#!/usr/bin/perl

#Search Utility for RLC BBx and VPro5 code

use Getopt::Std;	#Perl GetOpts Package

#Get Command Line Options
getopts("msvx:", \%opts) || die ;
$matched_text = defined $opts{m};
$string_vars = defined $opts{s};
$verbs_only = defined $opts{v};
$exclude_regex = $opts{x};

#Check Command Line Arguments
if (scalar @ARGV != 1) {
	print "RLC Program Search Utility\n";
	print "Searches specific directories and ignores contents of REM statements\n";
	print "Usage: $0 [OPTION] REGEX\n";
	print "Options: -m  output matched text only\n";
	print "         -s  include string variable assignments\n";
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
		next if (index($file, '.')>-1); #Skip Files with Dot in File Name
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
		foreach (@results) { print "\t$_\n"; }
		print "\n";
	}
}

#Search Line in File
#Parameters: Text of Line to Search
sub search_line {
	my $line = $_[0];
	my @results;	#Results of Line Search
	undef @do_matches;
	my $do_results;	#Results of each Call to do_searches
	#Skip Lines Beginning with REM
	next if ($line =~ /^[0-9]+\s*REM\s/);
	#Isolate trailing REM from Line
	if ($line =~ /(.*)(;\s*REM\s+.*$)/) {
		die "Bad REM split on line $line\n" if ("$1$2" ne $line);
		my $quotes = $1 =~ tr/\"//;	#Count number of Quotes in Code part of Line
		die "Odd number of Quotes after REM split on line $line" if ($quotes % 1);
		$do_results = do_searches($1);
	} else {
		$do_results = do_searches($line);
	}
	###print "Results: @do_results" if (@do_results);
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
	my $matches;
	return 0 if $exclude_regex && $text =~ /$exclude_regex/;
	if ($verbs_only) {
		#Search for Expression after a Line Number
		$matches = my @lno_matches = $text =~  /^[0-9]+\s+($regex)/;
		#Search for Expression after a Colon or Semicolon
		$matches += my @lbl_matches = $text =~  /[:;]\s+($regex)/g;
		push @do_matches, @lno_matches, @lbl_matches;
	} else {
		$matches = @do_matches = $text =~  /$regex/g;
	}
	$total_matches += $matches;
	if ($matches) {
		return $text;
	} else {
		return 0;
	}
}
