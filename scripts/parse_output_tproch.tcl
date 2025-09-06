#!/bin/tclsh
# Procedure to get the job ID from the output file
proc getjobid {filename} {
    set fd [open $filename r]
    set jobid [lindex [split [gets $fd] =] 1]
    close $fd
    return $jobid
}

# Main script execution
set tmpdir $::env(TMPDIR)
set ::outputfile  $tmpdir/mssqls_tproch
set filename $::outputfile
set jobid [getjobid $filename]

if {$jobid eq ""} {
    puts "Job ID not found in the output file."
    exit 1
}

set output_filename [file normalize "${filename}_${jobid}.out"]

# Open the file for writing
set fileId [open $output_filename "w"]

# Write to the file
puts $fileId "TPC-H QUERY EXECUTION RESULTS"
puts $fileId "============================="
puts $fileId ""
puts $fileId "QUERY TIMING RESULTS"
puts $fileId [job $jobid timing]
puts $fileId ""
puts $fileId "HAMMERDB RESULT SUMMARY"
puts $fileId [job $jobid result]

# Close the file
close $fileId

# Print the output to the console
set output [exec cat $output_filename]
puts $output