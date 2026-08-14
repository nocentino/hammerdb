#!/bin/tclsh
# Compatibility shim for HammerDB 6.0.
#
# "jobs <jobid> save" writes an AI-friendly JSON report, but the shipped 6.0
# Linux binary fails with:
#
#   Error: invalid command name "jobs_summary_public_config"
#   Error: invalid command name "jobs_summary_missing_data"
#   Error: Could not save JSON report: expected boolean value but got ""
#
# leaving a zero byte file. Its jobs_save_json calls two helpers that exist in
# the v6.0 source (modules/jobs-1.0.tm) but are absent from the released
# starpack, which was built from an earlier commit. The released binary embeds
# its modules in a password protected VFS that takes precedence over
# /opt/HammerDB-6.0/modules, so dropping the newer module on disk does not
# override it - the helpers have to be defined at runtime instead.
#
# The definitions below are taken verbatim from modules/jobs-1.0.tm at tag v6.0.
# Both are self contained, using only hdbjobs and core Tcl.
#
# Every definition is guarded, so this becomes a no-op once a HammerDB release
# ships the helpers. Source it before calling "jobs <jobid> save".
#
# Sets ::hammerdb6_jobs_save_usable to 1 when the command should work.

namespace eval ::jobs {

    if {[llength [info procs ::jobs::jobs_summary_public_config]] == 0} {
        proc jobs_summary_public_config {jobid avu {bm "TPROC-C"}} {
            set cfg [dict create]
            set raw [join [hdbjobs eval {SELECT jobdict FROM JOBMAIN WHERE JOBID=$jobid}]]

            if {$bm eq "TPROC-H"} {
                if {$raw ne "" && ![catch {dict get $raw tpch} tpch]} {
                    foreach {key value} $tpch {
                        if {[string match "*_scale_fact*" $key] || [string match "*_scale_factor*" $key]} {
                            dict set cfg scale_factor $value
                        }
                    }
                }
                if {![dict exists $cfg scale_factor]} {
                    set output1 [join [hdbjobs eval {SELECT OUTPUT FROM JOBOUTPUT WHERE JOBID=$jobid AND VU=1}]]
                    if {[regexp -nocase {scale[[:space:]]+factor[^0-9]*([0-9]+)} $output1 -> sf]} {
                        dict set cfg scale_factor $sf
                    }
                }
            } else {
                if {$raw ne "" && ![catch {dict get $raw tpcc} tpcc]} {
                    foreach {key value} $tpcc {
                        if {[string match "*_count_ware" $key]} {
                            dict set cfg warehouses $value
                        } elseif {[string match "*_rampup" $key]} {
                            dict set cfg rampup_minutes $value
                        } elseif {[string match "*_duration" $key]} {
                            dict set cfg duration_minutes $value
                        }
                    }
                }
                if {$avu ne ""} {
                    dict set cfg virtual_users $avu
                }
            }
            return $cfg
        }
    }

    if {[llength [info procs ::jobs::jobs_summary_missing_data]] == 0} {
        proc jobs_summary_missing_data {value message} {
            if {[catch {dict get $value message} msg] == 0 && $msg eq $message} {
                return 1
            }
            if {[llength $value] == 2 && [lindex $value 1] eq $message} {
                return 1
            }
            return 0
        }
    }
}

# jobs_save_json itself must exist for any of this to help
set ::hammerdb6_jobs_save_usable \
    [expr {[llength [info procs ::jobs::jobs_save_json]] > 0
           && [llength [info procs ::jobs::jobs_summary_public_config]] > 0
           && [llength [info procs ::jobs::jobs_summary_missing_data]] > 0}]
