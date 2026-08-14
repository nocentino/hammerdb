#!/bin/tclsh
# Compare two TPROC-C performance profiles.
#
# Runs tagged with PROFILE_ID during the load phase can be compared here, which
# replaces eyeballing two separate result blobs when testing configurations
# against each other (SQL Server versions, storage, instance sizes).
#
# Required:
#   BASE_PROFILE_ID   baseline/reference profile id
#   COMP_PROFILE_ID   profile compared relative to the baseline
# Optional:
#   WEIGHTED_COMPARE  true|false  (default false) weighted compare mode
#   REPORT_JSON       true|false  (default true)  write a JSON report
#   SAVE_CHARTS       true|false  (default true)  write an HTML comparison chart
#
# Writes to TMP:
#   tprocc_profile_<base>_vs_<comp>.json
#   tprocc_profile_<base>_vs_<comp>.html

proc envdef {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} {
        return $::env($name)
    }
    return $default
}

# Run a command that writes to stdout and return what it wrote. The jobs
# subcommands print their output rather than returning it.
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

# Run a command, discard what it writes to stdout, and return its result.
# "jobs ... getchart diff:" returns the chart but also reprints the comparison,
# which this suppresses so it is not reported twice.
proc quietcli {script} {
    rename ::puts ::_real_puts
    proc ::puts {args} {
        if {[lindex $args 0] eq "-nonewline"} {
            set args [lrange $args 1 end]
        }
        if {[llength $args] == 1 || [lindex $args 0] eq "stdout"} {
            return
        }
        ::_real_puts {*}$args
    }
    set code [catch {uplevel 1 $script} result]
    rename ::puts {}
    rename ::_real_puts ::puts
    if {$code} { return -code error $result }
    return $result
}

proc jsonstring {s} {
    set map [list "\\" "\\\\" "\"" "\\\"" "\n" "\\n" "\r" "\\r" "\t" "\\t"]
    return "\"[string map $map $s]\""
}

# Embed already-formatted JSON verbatim, otherwise emit a JSON string
proc jsonvalue {s} {
    set t [string trim $s]
    if {$t eq ""} { return "null" }
    set c [string index $t 0]
    if {$c eq "\{" || $c eq "\["} { return $t }
    return [jsonstring $s]
}

proc runsection {label script} {
    if {[catch {set value [capturecli $script]} msg]} {
        puts "WARNING: $label failed: $msg"
        return ""
    }
    return $value
}

# Validate required environment variables
foreach var {BASE_PROFILE_ID COMP_PROFILE_ID TMP} {
    if {![info exists ::env($var)] || $::env($var) eq ""} {
        puts "Error: Environment variable $var is not set or empty."
        exit 1
    }
}

set tmpdir $::env(TMP)
set base $::env(BASE_PROFILE_ID)
set comp $::env(COMP_PROFILE_ID)
set weighted [envdef WEIGHTED_COMPARE false]
set report_json [envdef REPORT_JSON true]
set save_charts [envdef SAVE_CHARTS true]

puts "COMPARING TPROC-C PERFORMANCE PROFILES"
puts "  Baseline profile id:   $base"
puts "  Comparison profile id: $comp"
puts "  Weighted compare:      $weighted"

jobs format JSON

set known [runsection "profile list" {jobs profileid all}]
puts "KNOWN PROFILE IDS"
puts $known

set baseresult [runsection "baseline profile" [list jobs profile $base]]
puts "BASELINE PROFILE $base"
puts $baseresult

set compresult [runsection "comparison profile" [list jobs profile $comp]]
puts "COMPARISON PROFILE $comp"
puts $compresult

set diffresult [runsection "profile diff" [list jobs diff $base $comp $weighted]]
puts "PROFILE DIFF $base VS $comp"
puts $diffresult

if {$baseresult eq "" && $compresult eq ""} {
    puts "Error: neither profile id returned any results. Tag runs with PROFILE_ID"
    puts "during the load phase before comparing them."
    exit 1
}

if {$report_json eq "true"} {
    set reportfile $tmpdir/tprocc_profile_${base}_vs_${comp}.json
    set pairs {}
    lappend pairs "  \"base_profile_id\": \"$base\""
    lappend pairs "  \"comparison_profile_id\": \"$comp\""
    lappend pairs "  \"weighted\": \"$weighted\""
    lappend pairs "  \"known_profile_ids\": [jsonvalue $known]"
    lappend pairs "  \"base\": [jsonvalue $baseresult]"
    lappend pairs "  \"comparison\": [jsonvalue $compresult]"
    lappend pairs "  \"diff\": [jsonvalue $diffresult]"

    if {[catch {
        set fh [open $reportfile w]
        # Chart and report content can contain non-ASCII, and the container's
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

# Comparison chart. For profile charts the profile id takes the jobid position.
if {$save_charts eq "true"} {
    if {[catch {set html [quietcli [list jobs $base getchart diff:$comp]]} msg]} {
        puts "WARNING: could not generate comparison chart: $msg"
    } elseif {[string trim $html] eq ""} {
        puts "WARNING: comparison chart was empty, skipping"
    } else {
        set chartfile $tmpdir/tprocc_profile_${base}_vs_${comp}.html
        if {[catch {
            set fh [open $chartfile w]
            fconfigure $fh -encoding utf-8
            puts $fh $html
            close $fh
        } msg]} {
            puts "WARNING: could not write comparison chart to $chartfile: $msg"
        } else {
            puts "CHART: $chartfile"
        }
    }
}

puts "PROFILE COMPARISON COMPLETE"
