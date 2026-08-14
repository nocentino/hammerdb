#!/bin/tclsh
# Parse TPROC-H results.
#
# Keeps the original text report at TMP/mssqls_tproch_<jobid>.out, and adds:
#   - a single JSON report  : TMP/tproch_<jobid>.json        (REPORT_JSON=true)
#   - HTML charts           : TMP/tproch_<jobid>_<type>.html (SAVE_CHARTS=true)
#
# See parse_output_tprocc.tcl for why the report is assembled here rather than
# using HammerDB 6.0's "jobs <jobid> save", and why capturecli is needed.

# Optional settings, defaulted so existing env files keep working
proc envdef {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} {
        return $::env($name)
    }
    return $default
}

# Run a command that writes to stdout and return what it wrote.
proc capturecli {script} {
    global _capbuf
    set _capbuf ""
    rename ::puts ::_real_puts
    proc ::puts {args} {
        global _capbuf
        set nl 1
        if {[lindex $args 0] eq "-nonewline"} {
            set nl 0
            set args [lrange $args 1 end]
        }
        # Capture stdout writes, pass anything else through to the real puts
        if {[llength $args] == 1 || [lindex $args 0] eq "stdout"} {
            append _capbuf [lindex $args end]
            if {$nl} { append _capbuf "\n" }
            return
        }
        if {$nl} {
            ::_real_puts {*}$args
        } else {
            ::_real_puts -nonewline {*}$args
        }
    }
    set code [catch {uplevel 1 $script} result]
    rename ::puts {}
    rename ::_real_puts ::puts
    if {$code} { return -code error $result }
    return [string trimright $_capbuf "\n"]
}

# Fetch one section of a job as JSON, or "null" if it is unavailable
proc jobsection {jobid subcommand} {
    if {[catch {set value [capturecli [list jobs $jobid $subcommand]]} msg]} {
        puts "WARNING: could not read '$subcommand' for job $jobid: $msg"
        return "null"
    }
    if {[string trim $value] eq ""} {
        return "null"
    }
    # When a section has no data HammerDB emits "Jobid has no <x> data", which
    # its JSON formatter mangles into {"Jobid": "has", "no": "...", ...}.
    # Report that as null rather than passing fabricated fields through.
    # TPROC-H has no xtprof timing data, so this is the normal case for timing.
    if {[regexp {"Jobid"\s*:\s*"has"} $value]} {
        return "null"
    }
    return $value
}

# Procedure to get the job ID from the output file
proc getjobid {filename} {
    set fd [open $filename r]
    set line [string trim [gets $fd]]
    close $fd
    # Accepts "jobid=<id>", "Benchmark Run jobid=<id>", or a bare id, since the
    # metrics collector rewrites the job id HammerDB hands back.
    if {[regexp {=(.*)$} $line -> id]} {
        return [string trim $id]
    }
    return $line
}

# Main script execution
set tmpdir $::env(TMP)
set report_json [envdef REPORT_JSON true]
set save_charts [envdef SAVE_CHARTS true]

set ::outputfile  $tmpdir/mssqls_tproch
set filename $::outputfile
set jobid [getjobid $filename]

if {$jobid eq ""} {
    puts "Job ID not found in the output file."
    exit 1
}

jobs format JSON

# Collect every section once, then reuse for the text report, the console, and
# the JSON report. TPC-H has no transaction counter, so tcount is not collected.
set section_order {benchmark bm database db timestamp timestamp status status \
                   result result timing timing system system}
set collected [dict create]
foreach {name subcommand} $section_order {
    dict set collected $name [jobsection $jobid $subcommand]
}

# Original text report, kept for compatibility
set output_filename [file normalize "${filename}_${jobid}.out"]
if {[catch {
    set fileId [open $output_filename "w"]
    fconfigure $fileId -encoding utf-8
    puts $fileId "TPC-H QUERY EXECUTION RESULTS"
    puts $fileId "============================="
    puts $fileId ""
    puts $fileId "QUERY TIMING RESULTS"
    puts $fileId [dict get $collected timing]
    puts $fileId ""
    puts $fileId "HAMMERDB RESULT SUMMARY"
    puts $fileId [dict get $collected result]
    close $fileId
} msg]} {
    puts "WARNING: could not write text report to $output_filename: $msg"
} else {
    puts "TEXT REPORT: $output_filename"
}

# Print to the console
puts "QUERY TIMING RESULTS"
puts [dict get $collected timing]

puts "HAMMERDB RESULT"
puts [dict get $collected result]

# Single JSON report combining every section of the job
if {$report_json eq "true"} {
    set reportfile $tmpdir/tproch_${jobid}.json
    set pairs {}
    # No profile_id here: HammerDB performance profiles are TPROC-C only.
    lappend pairs "  \"jobid\": \"$jobid\""
    foreach {name subcommand} $section_order {
        lappend pairs "  \"$name\": [dict get $collected $name]"
    }

    if {[catch {
        set fh [open $reportfile w]
        # Report and chart content can contain non-ASCII, and the container's
        # default locale is not UTF-8, so set the channel encoding explicitly.
        fconfigure $fh -encoding utf-8
        puts $fh "\{"
        puts $fh [join $pairs ",\n"]
        puts $fh "\}"
        close $fh
    } msg]} {
        puts "WARNING: could not write JSON report to $reportfile: $msg"
    } else {
        puts "JSON REPORT: $reportfile"
    }

    # HammerDB's own richer report via "jobs <jobid> save". The 6.0 binary ships
    # broken; hammerdb6_compat.tcl restores the helpers it needs and becomes a
    # no-op once a release includes them.
    set compat [file join [file dirname [info script]] hammerdb6_compat.tcl]
    if {![file exists $compat]} {
        set compat /opt/HammerDB-6.0/scripts/hammerdb6_compat.tcl
    }
    if {[catch {source $compat} msg]} {
        puts "WARNING: could not load the HammerDB 6.0 compat shim: $msg"
    } elseif {!$::hammerdb6_jobs_save_usable} {
        puts "WARNING: this HammerDB build cannot write a native job report"
    } elseif {[catch {jobs $jobid save} msg]} {
        puts "WARNING: could not write the native job report: $msg"
    } else {
        puts "NATIVE REPORT: $tmpdir/hdb_${jobid}.json"
    }
}

# HTML charts, rendered by HammerDB and returned as a string
if {$save_charts eq "true"} {
    foreach charttype {result timing} {
        if {[catch {set html [jobs $jobid getchart $charttype]} msg]} {
            puts "WARNING: could not generate $charttype chart: $msg"
            continue
        }
        if {[string trim $html] eq ""} {
            puts "WARNING: $charttype chart was empty, skipping"
            continue
        }
        set chartfile $tmpdir/tproch_${jobid}_${charttype}.html
        if {[catch {
            set fh [open $chartfile w]
            fconfigure $fh -encoding utf-8
            puts $fh $html
            close $fh
        } msg]} {
            puts "WARNING: could not write $charttype chart to $chartfile: $msg"
        } else {
            puts "CHART: $chartfile"
        }
    }
}
