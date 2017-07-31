#!/usr/bin/perl

#TODO: make String Variable Name Search Recursive (and hope it doesn't go infinite...)

#Search for all SCALL references
#Prints to stdout: Lines containing SCALL verb and lines containing assignments
#	to string variables used in SCALL arguments

$rlcdir = 'RLC';	#Base Directory for Source Code Files
@subdirs = ('Legacy', 'VPro5');	#Subdirectories to search in


foreach (@subdirs) {
	$searchdir = "$rlcdir/$_";
	search_directory($searchdir);
}

#Search Directory
#Parameters: Directory to Search
sub search_directory {
	my $dirname = $_[0];
	#print "Searching directory '$dirname'\n";
	opendir my $dir, $dirname || die "Error opening directory '$dirname'\n";
	while ($file = readdir $dir) {
		next if (index($file, '.')>-1); #Skip Files with Dot in File Name
		$filespec = "$dirname/$file";
		if (-d $filespec) {
			search_directory($filespec);
		}
		elsif (-f $filespec) {
			search_file($filespec);
		}
		else {
			print "Skipping file '$filespec'\n";
		}
	}
	closedir $$dir;
}

#Search File
#Parameters: Filename of File to Search
sub search_file {
	$filename = $_[0];
	my $scall_count;
	undef %prog_lines;	#key = line#, data = line text
	undef @match_lines; #line# . matched text
	#print "Searching file '$filename'\n";
	open my $file, $filename || die "Error opening file '$filename'\n";
	while (my $line = readline $file) {
		$line =~ s/\r*\n*$//; #Strip CR and/or LF from line
		$scall_count += search_line($line);
	}
	close $file;
	if ($scall_count) {
		build_output();
	}
}

#Search Line in File
#Parameters: Text of Line to Search
#Updates: @match_lines, %prog_lines
#Returns: number of SCALL verbs found
sub search_line {
	my $line = $_[0];
	my $scall_count;	#Results of Line Search
	undef @do_results;	#Results of each Call to do_searches
	#Skip Lines Beginning with REM
	next if ($line =~ /^[0-9]+\s*REM\s/);
	#Isolate trailing REM from Line
	if ($line =~ /(.*)(;\s*REM\s+.*$)/) {
		die "Bad REM split on line $line\n" if ("$1$2" ne $line);
		my $quotes = $1 =~ tr/\"//;	#Count number of Quotes in Code part of Line
		die "Odd number of Quotes after REM split on line $line" if ($quotes % 1);
		$scall_count += do_searches($1);
	}
	else {
		$scall_count += do_searches($line);
	}
	###print "Results: @do_results" if (@do_results);
	#Prepend Line # to each Search Result
	if (@do_results) {
		my $line_no = join '', $line =~ ( /^([0-9]*)\s/ ); #Line Number at Beginning of Line	
		$prog_lines{$line_no} = $line;
		foreach (@do_results) {
			push @match_lines, "$line_no $_";
		}
		return $scall_count;
	}
}

#Do actual searches
#Parameter: text to search
#Updates: @do_results
#Returns: number of SCALL verbs found
sub do_searches {
	my $text = $_[0];
	my $scall_count;
	###print "Searching text: $text\n"; 
	#Get Line Number from Beginning of Line	
	my @strings = $text =~ ( /LET\s+(\w+\$\s*=\s*[^;,]*)/gi );
	push @strings, $text =~ ( /,\s*(\w+\$\s*=\s*[^;,]*)/gi );
	#Search for SCALL(s)
	my @scalls = $text =~ ( /(SCALL\([^\)]+\))/gi );
	###print "SCALLS: @scalls" if (@scalls);
	$scall_count = scalar @scalls;
	push @do_results, @strings, @scalls;
	return $scall_count;
}

#Process Search Results and Generate Output
#Uses: $file_name, @match_lines, %prog_lines
#            hash table containing matching program lines
sub build_output {
		undef %out_lines; #key = line#, data = program line
		undef %var_lines; #key = variable name, data = line#
		#Build Output Has Array
		foreach (@match_lines) {
			(my $line_no, my $line_text) = $_ =~ /^([0-9]*)\s(.*)/;
			if ( $line_text =~ /^SCALL\(/ ) {
				#Process String Variables in SCALL argument
				get_scall_vars();
				#Add line containing SCALL to Output
				$out_lines{$line_no} = $prog_lines{$line_no};
			}
			else {
				#Add/Replace Variable in Line Lookup Table
				my @var_names = $line_text =~ /(^\w+\$)/i;
				$var_lines{$var_names[0]} = $line_no;
			}
		}
		#Print Output Hash Array
		print "$filename\n";
		foreach my $line_no (sort {$a <=> $b} keys %out_lines) {
			print $out_lines{$line_no}, "\n";
        }
		print "\n";
}

#Find all String Variables in SCALL statement and Get Assignments
#Parameter: $line_text
#Updates: $prog_lines
sub get_scall_vars {
	undef %string_vars; #List of Processed String Vars to Prevent Infinite Recursion
	(my $scall_args) = $_ =~ /(\([^;]*)/;
	get_string_vars($scall_args); #Process Variables in Line
	
}

#Recursively Find all String Variables and Get Assignments
sub get_string_vars {
	my $search_text = $_[0];
	my @var_names = $search_text =~ /(\w+\$)/g;
	foreach (@var_names) {
		my $var_name = $_;
		next if $string_vars{$var_name};
		$string_vars{$var_name} = 1;
		my $line_no = $var_lines{$var_name};
		my $var_prog_line = $prog_lines{$line_no};
		$out_lines{$line_no} = $var_prog_line;
		#Process Strings after Equals Sign In Assignment
		(my $assign_text) = $var_prog_line =~ /\Q$var_name\E=([^;]*)/;
		get_string_vars($assign_text);
	}
}
