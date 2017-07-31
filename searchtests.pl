#!/usr/bin/perl

#Test Script for Searching RLC BBx and VPro5 code

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
	my @results;
	#print "Searching file '$filename'\n";
	open my $file, $filename || die "Error opening file '$filename'\n";
	while (my $line = readline $file) {
		$line =~ s/\r*\n*$//; #Strip CR and/or LF from line
		my @line_results = search_line($line);
		push @results, @line_results;
	}
	close $file;
	if (@results) {
		print "$filename\n";
		foreach (@results) {
			print "\t$_\n";
		}
	}
}

#Search Line in File
#Parameters: Text of Line to Search
sub search_line {
	my $line = $_[0];
	my @results;	#Results of Line Search
	my @do_results;	#Results of each Call to do_searches
	#Skip Lines Beginning with REM
	next if ($line =~ /^[0-9]+\s*REM\s/);
	#Isolate trailing REM from Line
	if ($line =~ /(.*)(;\s*REM\s+.*$)/) {
		die "Bad REM split on line $line\n" if ("$1$2" ne $line);
		my $quotes = $1 =~ tr/\"//;	#Count number of Quotes in Code part of Line
		die "Odd number of Quotes after REM split on line $line" if ($quotes % 1);
		@do_results = do_searches($1);
	}
	else {
		@do_results = do_searches($line);
	}
	###print "Results: @do_results" if (@do_results);
	#Prepend Line # to each Search Result
	my @line_no = $line =~ ( /^([0-9]*)\s/ ); #Line Number at Beginning of Line	
	foreach (@do_results) {
		push @results, "@line_no $_";
	}
	return @results;
}

#Do actual searches
#Parameter: text to search
#Returns: array containing search results
sub do_searches {
	my $text = $_[0];
	###print "Searching text: $text\n"; 
	#Search for SCALL(s)
	@matches = $text =~ ( /=\s*(SCALL\([^\)]+\))/g );
	return @matches;
}