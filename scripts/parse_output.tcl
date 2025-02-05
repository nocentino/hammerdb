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
set tmpdir /tmp
set ::outputfile  $tmpdir/mssqls_tprocc
set filename $::outputfile
set jobid [getjobid $filename]

if {$jobid eq ""} {
    puts "Job ID not found in the output file."
    exit 1
}

# Write output
puts "TRANSACTION RESPONSE TIMES"
puts [job $jobid timing]


puts "TRANSACTION COUNT"
puts [jobs $jobid tcount]

puts "HAMMERDB RESULT"
puts [jobs $jobid result]
