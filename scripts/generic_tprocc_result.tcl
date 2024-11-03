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

set output_filename [file normalize "${filename}_${jobid}.out"]

# Open the file for writing
set fileId [open $output_filename "w"]

# Write to the file
puts $fileId "TRANSACTION RESPONSE TIMES"
puts $fileId [job $jobid timing]

puts $fileId "TRANSACTION COUNT"
puts $fileId [job $jobid tcount]

puts $fileId "HAMMERDB RESULT"
puts $fileId [job $jobid result]

# Close the file
close $fileId

# Optionally, print the output to the console
set output [getoutput $output_filename]
puts $output
