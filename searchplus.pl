#!/usr/bin/perl

#Search for all statement references
#Prints to stdout: Lines containing specified verb and lines containing assignments
#	to string variables used in arguments to those verbs

$ARGC = scalar @ARGV;

#Check Command Line Arguments
if ($ARGC < 1 || $ARGC > 2) {
	print "RLC Improved Verb Search Utility\n";
	print "Searches specific directories and ignores contents of REM statements\n";
	print "Outputs all statetments using the specified verb\n";
	print "and assignments to strings used in those statements\n";
	print "Usage: $0 VERB [ARGS]\n";
	exit;
}

#Set Search Directories
$rlcdir = 'RLC';	#Base Directory for Source Code Files
@subdirs = ('Legacy', 'VPro5');	#Subdirectories to search in

#Set Verb to Search For
$verb = $ARGV[0]; 
$args = $ARGC > 1 ? $ARGV[1] : '\w';

print "Searching for verb '$verb'\n";
print "\n";

foreach (@subdirs) {
	$searchdir = "$rlcdir/$_";
	search_directory($searchdir);
}
print "Total matches against '$verb' ";
print "with argument(s) '$args' " if $args;
print "= $total_statements\n";

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
			$total_statements += search_file($filespec);
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
	my $statement_count;
	undef %prog_lines;	#key = line#, data = line text
	undef @match_lines; #line# . matched text
	#print "Searching file '$filename'\n";
	open my $file, $filename || die "Error opening file '$filename'\n";
	while (my $line = readline $file) {
		$line =~ s/\r*\n*$//; #Strip CR and/or LF from line
		$statement_count += search_line($line);
	}
	close $file;
	if ($statement_count) {
		build_output();
	}
	return $statement_count;
}

#Search Line in File
#Parameters: Text of Line to Search
#Updates: @match_lines, %prog_lines
#Returns: number of statement verbs found
sub search_line {
	my $line = $_[0];
	my $statement_count;	#Results of Line Search
	undef @do_results;	#Results of each Call to do_searches
	#Skip Lines Beginning with REM
	next if ($line =~ /^[0-9]+\s*REM\s/);
	#Isolate trailing REM from Line
	if ($line =~ /(.*)(;\s*REM\s+.*$)/) {
		die "Bad REM split on line $line\n" if ("$1$2" ne $line);
		my $quotes = $1 =~ tr/\"//;	#Count number of Quotes in Code part of Line
		die "Odd number of Quotes after REM split on line $line" if ($quotes % 1);
		$statement_count += do_searches($1);
	}
	else {
		$statement_count += do_searches($line);
	}
	print "Results: @do_results" if @do_results && $debug;
	#Prepend Line # to each Search Result
	if (@do_results) {
		my $line_no = join '', $line =~ ( /^([0-9]*)\s/ ); #Line Number at Beginning of Line	
		$prog_lines{$line_no} = $line;
		foreach (@do_results) {
			push @match_lines, "$line_no $_";
		}
		return $statement_count;
	}
}

#Do actual searches
#Parameter: text to search
#Updates: @do_results
#Returns: number of statement verbs found
sub do_searches {
	my $text = $_[0];
	my $statement_count;
	print "Searching text: $text\n" if $debug; 
	#Extract String Assignments from Line
	my @strings = $text =~ ( /LET\s+(\w+\$\s*=\s*[^;,]*)/gi );
	push @strings, $text =~ ( /,\s*(\w+\$\s*=\s*[^;,]*)/gi );
	#Search for statement(s)
	my @statements = $text =~ ( /[0-9]+\s+($verb\s+$args[^;]*)/gi );
	push @statements, $text =~ ( /[:;]\s+($verb\s+$args[^;]*)/gi );
	push @statements, $text =~ ( /THEN\s+($verb\s+$args[^;]*)/gi );
	push @statements, $text =~ ( /ELSE\s+($verb\s+$args[^;]*)/gi );
	print "statements: @statements\n" if @statements && $debug;
	$statement_count = scalar @statements;
	push @do_results, @strings, @statements;
	return $statement_count;
}

#Process Search Results and Generate Output
#Uses: $file_name, @match_lines, %prog_lines
#            hash table containing matching program lines
sub build_output {
	print "Building Output for file $filename\n" if $debug;
	undef %out_lines; #key = line#, data = program line
	undef %var_lines; #key = variable name, data = line#
	#Build Output Has Array
	foreach (@match_lines) {
		(my $line_no, my $line_text) = $_ =~ /^([0-9]*)\s(.*)/;
		print "Processing $line_no $line_text\n" if $debug;
		if ( $line_text =~ /^$verb/ ) {
			#Process String Variables in statement argument
			get_statement_vars($line_text);
			#Add line containing statement to Output
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

#Find all String Variables in statement statement and Get Assignments
#Parameter: $line_text
#Updates: $prog_lines
sub get_statement_vars {
	undef %string_vars; #List of Processed String Vars to Prevent Infinite Recursion
	(my $statement_args) = $_[0] =~ /^$verb\s+([^;]*)/;
	get_string_vars($statement_args); #Process Variables in Line
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
