#!/usr/bin/perl

#Master Search and Replace Utility for RLC BBx and VPro5 code

use Getopt::Std;	#Perl GetOpts Package

#Get Command Line Options
getopts("u", \%opts) || die ;
$unreplaced_only = defined $opts{u};

#TEST VERSION: 
#Does not change any copde
#Outputs Program Name, Old Line and New Line 

#Set Search Directories
$rlcdir = 'RLC';	#Base Directory for Source Code Files
@subdirs = ('Legacy', 'VPro5');	#Subdirectories to search in

set_regex_globals();	#Set Regular Expression Globals

if (@ARGV) {
	foreach (@ARGV) {
		search_file($_);
	}
} else {
	foreach (@subdirs) {
		$searchdir = "$rlcdir/$_";
		search_directory($searchdir);
	}
}
print "Total Replacements: $replacements\n";
print "Total Not Replaced: $unreplacements\n";

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
	$use_RL = 
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
		print "\n";
	}
}

#Search Line in File
#Parameters: Text of Line to Search
sub search_line {
	my $line = $_[0];
	my @results;	#Results of Line Search
	undef @unreplaced; #Unreplaced Matches
	#Skip Lines Beginning with REM
	next if ($line =~ /^[0-9]+\s*REM\s/);
	#Isolate trailing REM from Line
	if ($line =~ /(.*)(;\s*REM\s+.*$)/) {
		die "Bad REM split on line $line\n" if ("$1$2" ne $line);
		my $quotes = $1 =~ tr/\"//;	#Count number of Quotes in Code part of Line
		die "Odd number of Quotes after REM split on line $line" if ($quotes % 1);
		$replaced_line = do_replaces($1) . $2;
	}
	else {
		$replaced_line = do_replaces($line);
	}
	if ($replaced_line ne $line && ! $unreplaced_only) {
		push @results, "OLD: $line", "NEW: $replaced_line";
	}
	$line_no = join "", $line =~ /(^[0-9]+)/;
	foreach (@unreplaced) {
		push @results, "N/R: $line_no $_";
		$unreplacements += @unreplaced; #Total Number of Non-Replacements
	}
	return @results;
}

#Do Searches & Replacements
#Parameter: text to search and replace
#Sets: $text - text to search and replace
#Returns: text after search and replace
sub do_replaces {
	$text = $_[0];
	#do_rl_open();	#Replace OPEN () with RL.Open()
	#do_rl_path();	#Insert RL.Path()
	do_rl_path_call();	#Insert RL.Path() in CALL statements
	#do_rl_path_run();	#Insert RL.Path() in RUN statements
	#do_rl_rename();	#Replcase RENAME with RL.Rename()
	return $text;
}

#Replace OPEN Verb with Call to Static Methoc RL.Open()
#Updates: $text - text to search and replace
#		  $replacements - number of replacements made
sub do_rl_open {
	#Replace  OPEN (chan)filespec  with  RL.Open(chan,filespec)
	$replacements += $text =~  s/(?<![\w\.])OPEN\s*\(($chanex)\)\s*($filex)/RL.Open($1,$2)/g;
	#Replace  OPEN (chan,ERR=linelabel)filespec  with  RL.Open(chan,filespec,ERR=linelabel)
	$replacements += $text =~  s/(?<![\w\.])OPEN\s*\(($chanex),(ERR|err)=($errex)\)\s*($filex)/RL.Open($1,$4,$2=$3)/g;
	#Replace  OPEN (chan,ERR=linelabel,ISZ==expr)filespec  with  RL.Open(chan,filespec,expr,ERR=linelabel)
	###$replacements += $text =~  s/(?<![\w\.])OPEN\s*\(($chanex),(ERR|err)=($errex),ISZ=([0-9\-]*)\)\s*($filex)/RL.Open($1,$5,$4,$2=$3)/g;
	#Replace  OPEN (chan,MODE="modestring")filespec  with  RL.Open(chan,filespec,"modestring")
	$replacements += $text =~  s/(?<![\w\.])OPEN\s*\(($chanex),MODE=($modex)\)\s*($filex)/RL.Open($1,$3,$2)/g;
	#Replace  OPEN (chan,MODE="modestring",ERR=linelabel)filespec with  RL.Open(chan,filespec,"modestring",ERR=linelabel)
	$replacements += $text =~  s/(?<![\w\.])OPEN\s*\(($chanex),MODE=($modex),(ERR|err)=($errex)\)\s*($filex)/RL.Open($1,$5,$2,$3=$4)/g;
	#Find number of unchanged OPEN statements
	push @unreplaced, $text =~ /(?<![\w\.\"])(OPEN\s*\(\w+[^;]*)/gi;
}

#Insert RL.Path where appropriate
#Updates: $text - text to search and replace
#		  $replacements - number of replacements made
sub do_rl_path {
	#Replace  line# VERB filespec  with line# VERB RL.Path(filespec)
	$replacements += $text =~  s/(^[0-9]+)\s+($file_verbs)\s+([^,;]*)/$1 $2 RL\.Path\($3\)/g;
	#Replace  : line# VERB filespec,  with  : VERB RL.Path(filespec),
	#Replace  ; line# VERB filespec,  with  ; VERB RL.Path(filespec),
	$replacements += $text =~  s/(:|;)\s+($file_verbs)\s+([^,;]*)/$1 $2 RL\.Path\($3\)/g;
	#Find Number of unchanged VERB statements
	$unreplaced +- $text =~ /^[0-9]+\s+($file_verbs)\s/g;
	$unreplaced +- $text =~ /[:;]\s*($file_verbs)\s/g;
}

#Insert RL.Path in appropriate CALL Statements
#Updates: $text - text to search and replace
#		  $replacements - number of replacements made
sub do_rl_path_call {
	#Replace  CALL filespec  with line# CALL RL.Path(filespec)
	$replacements += $text =~  s/\s+(CALL)\s+($absex)/ $1 RL\.Path\($2\)/g;
}

#Insert RL.Path in appropriate RUN Statements
#Updates: $text - text to search and replace
#		  $replacements - number of replacements made
sub do_rl_path_run {
	#Replace  RUN filespec  with line# RUN RL.Path(filespec)
	$replacements += $text =~  s/\s+(RUN)\s+($absex)/ $1 RL\.Path\($2\)/g;
}

#Replace RENAME Verb with Call to Static Methoc RL.Rename()
#Updates: $text - text to search and replace
#		  $replacements - number of replacements made
sub do_rl_rename {
	#Replace  line# RENAME fromspec,tospec,ERR=linelabel  with  line# RL.Rename(frompec,tospec,ERR=linelabel)
	$replacements += $text =~  s/(^[0-9]+)\s+RENAME\s+(.*?),(.*?),ERR=([^;]*)/$1 RL.Rename($2,$3,ERR=$4)/g;
	#Replace  line# RENAME fromspec TO tospec,ERR=linelabel  with  line# RL.Rename(frompec,tospec,ERR=linelabel)
	$replacements += $text =~  s/(^[0-9]+)\s+RENAME\s+(.*?)\s+TO\s+(.*?),ERR=([^;]*)/$1 RL.Rename($2,$3,ERR=$4)/g;
	#Replace  THEN RENAME fromspec,tospec,ERR=linelabel  with  THEN RL.Rename(frompec,tospec,ERR=linelabel)
	$replacements += $text =~  s/\sTHEN\s+RENAME\s+(.*?),(.*?),ERR=(\w*)/ THEN RL.Rename($1,$2,ERR=$3)/g;
	#Replace  ; RENAME fromspec,tospec,ERR=linelabel  with  ; RL.Rename(frompec,tospec,ERR=linelabel)
	$replacements += $text =~  s/;\s+RENAME\s+(.*?),(.*?),ERR=([^;]*)/; RL.Rename($1,$2,ERR=$3)/g;
	#Replace  line# RENAME fromspec TO tospec  with  line# RL.Rename(frompec,tospec)
	$replacements += $text =~  s/(^[0-9]+)\s+RENAME\s+(.*?)\s+TO\s+([^;]*)/$1 RL.Rename($2,$3)/g;
	#Replace  line# RENAME fromspec,tospec  with  line# RL.Rename(frompec,tospec)
	$replacements += $text =~  s/(^[0-9]+)\s+RENAME\s+(.*?),([^;]*)/$1 RL.Rename($2,$3)/g;
	#Replace  ; RENAME fromspec,tospec  with  ; RL.Rename(frompec,tospec)
	$replacements += $text =~  s/;\s+RENAME\s+(.*?),([^;]*)/; RL.Rename($2,$3)/g;
	#Replace  THEN RENAME fromspec,tospec  with  THEN RL.Rename(frompec,tospec)
	$replacements += $text =~  s/\sTHEN\s+RENAME\s+(.*?),([^;]*)/ THEN RL.Rename($2,$3)/g;
	#Find number of unchanged RENAME statements
	$unreplaced += $text =~ /[0-9]+\s+RENAME\s+/g;
	$unreplaced += $text =~ /THEN\s+RENAME\s+/g;
	$unreplaced += $text =~ /[:;]\s*RENAME\s+/g;
}

#Set Global Variables used in Replacement Regular Expressions
sub set_regex_globals {
	#Verbs that Manipulate Files for RL.Path() Replacement
	$file_verbs = 'CHDIR|DIRECT|ERASE|FILE|INDEXED|INITFILE|MKEYED|SERIAL|SORT|STRING';
	#Regular Expression for Channel# In Open
	$chanex = '[\w\[\]\%\+\*\_\-]+'; #num, var, var%, var+val;, var-val, var*val
	$chanex .= '|[\w]+\(\w+\)'; #fnc(val)
	$chanex .= '|[\w]+\(\w+\$\([\w,]+\)\)'; #fnc(var$(expr))
	#Regular Expression for ERR= argument
	$errex = '\*?[\w\_]+'; 
	#Regular Expression for MODE= argument
	$modex = '"[^"]*"'; #"string"
	$modex .= '|"[^"]*"\+[\w\.]+\$'; #"string"+var$
	$modex .= '|"[^"]*"\+[\w\.]+\$\+"[^"]*"'; #"string"+var$+"string"
	$modex .= '|"[^"]*"\+[\w\.]+\$\+"[^"]*"\+[\w\.]+\$'; #"string"+var$+"string"+var$
	$modex .= '|"[^"]*"\+[\w]+\([\w\.]+\)\+"[^"]*"'; #"string"+fnc(var)+"string"
	$modex .= '|"[^"]*"\+[\w\.]+\$\+"[^"]*"\+[\w]+\([\w\.]+\)'; #"string"+var$+"string"+fnc(var)
	$modex .= '|"[^"]*"\+[^\+]+\+"[^"]*"+\+[^\+]+\+"[^"]*"'; #"string"+expr+"string"+expr+"string"
	#Regular Expression for filespec after OPEN
	$filex = '.[^\|][^;\s]*'; #any character + not a pipe + all characters not a semicolon or space 
	#Regular Expression for absolute path filespec
	$absex = '"\/[^; ]*'; #Literal String beginning with forward slash plus any non-semicolon
}