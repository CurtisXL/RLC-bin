#!/usr/bin/perl

#Search Utility for RLC BBx and VPro5 code

use Getopt::Std;	#Perl GetOpts Package

#Get Command Line Options
getopts("cmp:svx:", \%opts) || die ;
$show_counts = defined $opts{c};
$matched_text = defined $opts{m};
$string_vars = defined $opts{s};
$verbs_only = defined $opts{v};
$program_regex = $opts{p};
$exclude_regex = $opts{x};

if ($string_vars) {
	print "-s option not implemented\n";
	exit;
}

#Check Command Line Arguments
if (scalar @ARGV != 1) {
	print "RLC Program Search Utility\n";
	print "Searches specific directories and ignores contents of REM statements\n";
	print "Usage: $0 [OPTION] REGEX\n";
	print "Options: -c  display additional counts\n";
	print "         -m  output matched text only\n";
	print "         -p REGEX   only programs with line(s) matching regular expression\n";
	#print "         -s  include string variable assignments\n";
	print "         -v  search for verbs only\n";
	print "         -x REGEX   exclude lines matching regular expression\n";
	exit;
}

#Set Search Directories
$rlcdir = 'RLC';	#Base Directory for Source Code Files
@subdirs = ('Legacy', 'VPro5');	#Subdirectories to search in

#Set Regular Expression to Search For
$regex = $ARGV[0]; 

foreach (@subdirs) {
	$searchdir = "$rlcdir/$_";
	search_directory($searchdir);
}
if ($show_counts) {
	print "Total lines read: $lines_read\n";
	print "Total REMarks found: $rem_count\n";
	print "Totsl lines searched: $lines_searched\n";
	print "\n";
}
print "Total matches against '$regex' ";
print "excluding '$exclude_regex' " if $exclude_regex;
print "= $total_matches\n";

#Search Directory
#Parameters: Directory to Search
sub search_directory {
	my $dirname = $_[0];
	#print "Searching directory '$dirname'\n";
	opendir my $dir, $dirname || die "Error opening directory '$dirname'\n";
	while ($file = readdir $dir) {
		next if (index($file, '.')==0); #Skip File Name beginning with Dot
		$filespec = "$dirname/$file";
		if (-d $filespec) {
			search_directory($filespec);
		} elsif (-f $filespec) {
			search_file($filespec);
		} else {
			print "Skipping file '$filespec'\n";
		}
	}
	closedir $$dir;
}

#Search File
#Parameters: Filename of File to Search
sub search_file {
	$filename = $_[0];
	$file_prg_matches = 0; #Number of matches against -p option argument
	my @results;
	#print "Searching file '$filename'\n";
	open my $file, $filename || die "Error opening file '$filename'\n";
	while (my $line = readline $file) {
		$line =~ s/\r*\n*$//; #Strip CR and/or LF from line
		$lines_read += 1;
		my @line_results = search_line($line);
		push @results, @line_results;
	}
	close $file;
	return if ($program_regex && !$file_prg_matches); #Output only if -p option was matched
	if (@results) {
		print "$filename\n";
		foreach (@results) { print "\t$_\n"; }
		print "\n";
	}
}

#Search Line in File
#Parameters: Text of Line to Search
sub search_line {
	my $line = $_[0];
	my @results;	#Results of Line Search
	undef @do_matches; #Matches against regular expression
	undef @prog_matches; #Matches against -p option parameter
	my $do_results;	#Results of each Call to do_searches
	#Skip Lines Beginning with REM
	if ($line =~ /^[0-9]+\s*REM\s/i) {
		$rem_count += 1;
		return @results;
	}
	#Isolate trailing REM from Line
	$lines_searched += 1;
	if ($line =~ /(.*?)([;:]\s*REM\s+.*$)/i) {
		die "Bad REM split on line $line\n" if ("$1$2" ne $line);
		my $quotes = $1 =~ tr/\"//;	#Count number of Quotes in Code part of Line
		die "Odd number of Quotes after REM split on line $line" if ($quotes % 1);
		$rem_count += 1;
		$do_results = do_searches($1);
	} else {
		$do_results = do_searches($line);
	}
	print "Results: @do_results" if @do_results && $debug;
	#Prepend Line # to each Search Result
	my @line_no = $line =~ /^([0-9]*)\s/ ; #Line Number at Beginning of Line	
	if ($do_results) {
		if ($matched_text) {	#Prepend Line # to each Search Result
			foreach (@do_matches) { push @results, "@line_no $_"; }
		} else {
			push @results, $do_results;
		}
	}
	return @results;
	
}

#Do actual searches
#Parameter: text to search
#Returns: array containing search results
sub do_searches {
	my $text = $_[0];
	my $match_count;
	return 0 if $exclude_regex && $text =~ /$exclude_regex/;
	if ($verbs_only) {
		#Search for Expression after a Line Number
		$match_count = my @lno_matches = $text =~  /^[0-9]+\s+($regex)/;
		#Search for Expression after a Colon or Semicolon
		$match_count += my @lbl_matches = $text =~  /[:;]\s+($regex)/g;
		#Search for Expression after a THEN
		$match_count += my @then_matches = $text =~  /THEN\s+($regex)/g;
		#Search for Expression after an ELSE
		$match_count += my @else_matches = $text =~  /ELSE\s+($regex)/g;
		push @do_matches, @lno_matches, @lbl_matches, @then_matches, @else_matches;
	} else {
		$match_count = @do_matches = $text =~  /$regex/g;
	}
	$total_matches += $match_count;
    if ($program_regex) {
		my $prg_match_count = my @prg_matches = $text =~ /$program_regex/g;
		if ($prg_match_count) {
			print "prg_matches: @prg_matches\n" if $debug;
			push @do_matches, @prg_matches;
			$file_prg_matches += $prg_match_count;
		}
	}
	if ($match_count) {
		return $text;
	} else {
		return 0;
	}
}
