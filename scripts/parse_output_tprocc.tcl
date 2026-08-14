#!/bin/tclsh
# Parse TPROC-C results.
#
# Prints the same console output as before, and additionally writes:
#   - a single JSON report  : TMP/tprocc_<jobid>.json        (REPORT_JSON=true)
#   - HTML charts           : TMP/tprocc_<jobid>_<type>.html (SAVE_CHARTS=true)
#
# HammerDB 6.0 ships a "jobs <jobid> save" command intended to write an
# AI-friendly JSON report, but the shipped 6.0 binary is missing two procs it
# calls (jobs_summary_public_config / jobs_summary_missing_data) and it fails
# leaving an empty file. The report below is assembled from the individual job
# subcommands instead, which emit valid JSON once "jobs format JSON" is set.
#
# Those subcommands print their output rather than returning it, so capturecli
# temporarily replaces puts to collect it. "jobs ... getchart" is the exception
# and does return its HTML directly.

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
    return $value
}

# Procedure to get the job ID from the output file
proc getjobid {filename} {
    set fd [open $filename r]
    set jobid [lindex [split [gets $fd] =] 1]
    close $fd
    return $jobid
}

# Procedure to get the output from the output file
proc getoutput {filename} {
    set fd [open $filename r]
    set output [read $fd]
    close $fd
    return $output
}

# Main script execution
set tmpdir $::env(TMP)
set report_json [envdef REPORT_JSON true]
set save_charts [envdef SAVE_CHARTS true]
set profile_id [envdef PROFILE_ID 0]

set ::outputfile  $tmpdir/mssqls_tprocc
set filename $::outputfile
set jobid [getjobid $filename]

if {$jobid eq ""} {
    puts "Job ID not found in the output file."
    exit 1
}

# Set output as JSON
jobs format JSON

# Collect every section once, then reuse for both console output and the report
set section_order {benchmark bm database db timestamp timestamp status status \
                   result result transaction_count tcount timing timing system system}
set collected [dict create]
foreach {name subcommand} $section_order {
    dict set collected $name [jobsection $jobid $subcommand]
}

# Write output
puts "TRANSACTION RESPONSE TIMES"
puts [dict get $collected timing]

puts "TRANSACTION COUNT"
puts [dict get $collected transaction_count]

puts "HAMMERDB RESULT"
puts [dict get $collected result]

# Single JSON report combining every section of the job
if {$report_json eq "true"} {
    set reportfile $tmpdir/tprocc_${jobid}.json
    set pairs {}
    lappend pairs "  \"jobid\": \"$jobid\""
    lappend pairs "  \"profile_id\": \"$profile_id\""
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
}

# HTML charts, rendered by HammerDB and returned as a string
if {$save_charts eq "true"} {
    foreach charttype {result timing tcount} {
        if {[catch {set html [jobs $jobid getchart $charttype]} msg]} {
            puts "WARNING: could not generate $charttype chart: $msg"
            continue
        }
        if {[string trim $html] eq ""} {
            puts "WARNING: $charttype chart was empty, skipping"
            continue
        }
        set chartfile $tmpdir/tprocc_${jobid}_${charttype}.html
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
