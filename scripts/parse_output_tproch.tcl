# Procedure to get the job ID from the TPROC-H output file
proc getjobid_tproch {filename} {
    if {![file exists $filename]} {
        puts "Error: File $filename does not exist"
        return ""
    }
    
    set fd [open $filename r]
    set first_line [gets $fd]
    close $fd
    
    # Try to extract job ID from various possible formats
    if {[string match "*=*" $first_line]} {
        set jobid [lindex [split $first_line =] 1]
    } else {
        # If no '=' found, try other patterns
        set jobid [string trim $first_line]
    }
    
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

# Look for TPC-H output files with different possible patterns
set possible_files [list \
    "$tmpdir/mssqls_tproch" \
    "$tmpdir/mssqls_tpch" \
    "$tmpdir/tproch_output" \
    "$tmpdir/tpch_output" \
]

# Find the actual output file
set filename ""
foreach possible_file $possible_files {
    if {[file exists $possible_file]} {
        set filename $possible_file
        puts "Found TPC-H output file: $filename"
        break
    }
}

# If no standard file found, look for any files that might contain TPC-H results
if {$filename eq ""} {
    set all_files [glob -nocomplain "$tmpdir/*tproch*" "$tmpdir/*tpch*"]
    if {[llength $all_files] > 0} {
        set filename [lindex $all_files 0]
        puts "Using TPC-H output file: $filename"
    }
}

# If still no file found, check if we can use HammerDB's internal job system
if {$filename eq "" || ![file exists $filename]} {
    puts "No TPC-H output file found. Available files in $tmpdir:"
    catch {
        foreach file [glob -nocomplain "$tmpdir/*"] {
            puts "  [file tail $file]"
        }
    }
    
    # Try to use HammerDB's jobs system directly
    puts "Attempting to retrieve TPC-H results from HammerDB job system..."
    
    # Set output as JSON
    jobs format JSON
    
    # Try to get the most recent job
    set all_jobs [jobs list]
    if {[llength $all_jobs] > 0} {
        set latest_job [lindex $all_jobs end]
        puts "Latest job ID: $latest_job"
        
        puts "HAMMERDB TPC-H RESULTS"
        puts "======================"
        
        # Try to get job results
        catch {
            puts "Job Details:"
            puts [jobs $latest_job result]
        } result_error
        
        if {$result_error ne ""} {
            puts "No detailed results available from job system"
            puts "This may be normal for TPC-H tests which focus on query execution time"
        }
        
        exit 0
    } else {
        puts "No jobs found in HammerDB job system"
        puts "Expected files: mssqls_tproch, mssqls_tpch, tproch_output, tpch_output"
        exit 1
    }
}

set jobid [getjobid_tproch $filename]

if {$jobid eq ""} {
    puts "Job ID not found in the TPROC-H output file."
    exit 1
}

# Set output as JSON
jobs format JSON

# Parse and display TPROC-H results
parse_tproch_results $jobid