# Procedure to get the job ID from the TPROC-H output file
proc getjobid_tproch {filename} {
    set fd [open $filename r]
    set jobid [lindex [split [gets $fd] =] 1]
    close $fd
    return $jobid
}

# Procedure to get the output from the TPROC-H output file
proc getoutput_tproch {filename} {
    set fd [open $filename r]
    set output [read $fd]
    close $fd
    return $output
}

# Procedure to parse TPROC-H specific results
proc parse_tproch_results {jobid} {
    puts "TRANSACTION RESPONSE TIMES"
    puts [job $jobid timing]

    puts "TRANSACTION COUNT"
    puts [jobs $jobid tcount]

    puts "HAMMERDB RESULT"
    puts [jobs $jobid result]
}

# Main script execution
set tmpdir /tmp
set ::outputfile  $tmpdir/mssqls_tproch
set filename $::outputfile
set jobid [getjobid_tproch $filename]

if {$jobid eq ""} {
    puts "Job ID not found in the TPROC-H output file."
    exit 1
}

# Set output as JSON
jobs format JSON

# Parse and display TPROC-H results
parse_tproch_results $jobid