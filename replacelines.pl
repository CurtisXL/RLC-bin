#!/usr/bin/perl

#Master Search and Replace Utility for RLC BBx and VPro5 code

use File::Basename;
use Getopt::Std;	#Perl GetOpts Package

#Get Command Line Options
getopts("uw:", \%opts) || die ;
$unreplaced_only = defined $opts{u};
$write_dir = $opts{w}; #Directory to write updated programs to

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
	undef @prog_lines;
	#print "Searching file '$filename'\n";
	open my $file, $filename || die "Error opening file '$filename'\n";
	while (my $line = readline $file) {
		$line =~ s/\r*\n*$//; #Strip CR and/or LF from line
		my @line_results = search_line($line);
		push @results, @line_results;
		if (@line_results) {
			push @prog_lines, $replaced_line;
		} else {
			push @prog_lines, $line;
		}
	}
	close $file;
	if (@results) {
		print "$filename\n";
		foreach (@results) {
			print "\t$_\n";
		}
		print "\n";
		write_file() if $write_dir;
	}
}

#Search Line in File
#Parameters: Text of Line to Search
sub search_line {
	my $line = $_[0];
	my @results;	#Results of Line Search
	undef @unreplaced; #Unreplaced Matches
	#Skip Lines Beginning with REM
	next if ($line =~ /^[0-9]+\s*REM\s/i);
	#Isolate trailing REM from Line
	if ($line =~ /(.*?)([;i]\s*REM\s+.*$)/i) {
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
	#do_bbj_fixes();	#Fix bbjcpl Syntax Errors
	#do_rl_open();	#Replace OPEN () with RL.Open()
	#do_rl_path();	#Insert RL.Path()
	do_rlbase_u();	#Replace /rlbase and /u
	#do_rl_path_call();	#Insert RL.Path() in CALL statements
	#do_rl_path_run();	#Insert RL.Path() in RUN statements
	#do_rl_rename();	#Replcase RENAME with RL.Rename()
	#do_scall();			#Replace SCALL() with CALL "CDS180"
	return $text;
}

#Fix lines that create errors in bbjcpl
#Updates: $text - text to search and replace
#		  $replacements - number of replacements made
sub do_bbj_fixes {
	#Change  THEN var=  with  THEN LET var=
	#Change  THEN var$=  with  THEN LET var$=
	#Change  ELSE var=  with  ELSE LET var=
	#Change  ELSE var$=  with  ELSE LET var$=
	$replacements += $text =~  s/\s(THEN|ELSE)\s+(\w*\$?)=/ $1 LET $2=/g;
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

#Replace absolute path references to /rlbase and /u
#Updates: $text - text to search and replace
#		  $replacements - number of replacements made
sub do_rlbase_u {
	#Replace  "/rlbase/basis/pro5/"  with  STBL("PRO5DIR")+"
	$replacements += $text =~  s/$pro5ex/STBL\("PRO5DIR"\)\+"/g;
	#Replace  "/rlbase/CDI/"  with  STBL("SMSDIR")+"
	#Replace  "/u/CDI/"  with  STBL("SMSDIR")+"/
	$replacements += $text =~  s/$smsex/STBL\("SMSDIR"\)\+"/g;
}

#Insert RL.Path in appropriate CALL Statements
#Updates: $text - text to search and replace
#		  $replacements - number of replacements made
sub do_rl_path_call {
	#Replace  CALL "abspath"  with  CALL RL.Path("abspath")
	###$replacements += $text =~  s/\s(CALL)\s+($nop5ex)/ $1 RL\.Path\($2\)/g;
	#Replace  CALL "/rlbase/basis/pro5/"  with  CALL STBL("PRO5DIR")+"
	$replacements += $text =~  s/\s(CALL)\s+($pro5ex)/ $1 SCALL\("PRO5DIR"\)\+"/g;
	#Replace  CALL "/rlbase/CDI/"  with  CALL STBL("SMSDIR")+"
	#Replace  CALL "/u/CDI/"  with  CALL STBL("SMSDIR")+"/
	$replacements += $text =~  s/\s(CALL)\s+($smsex)/ $1 SCALL\("SMSDIR"\)\+"/g;
	#Replace  CALL MCH$+"abspath" with  CALL RL.Path("abspath")
	###$replacements += $text =~  s/\s(CALL)\s+MCH\$\+($callex)/ $1 RL\.Path\($2\)/g;
	#Find unchanged CALL "abspath" statements
	push @unreplaced, $text =~  /\s(CALL\s+$callex)/gi;
}

#Insert RL.Path in appropriate RUN Statements
#Updates: $text - text to search and replace
#		  $replacements - number of replacements made
sub do_rl_path_run {
	#Replace  RUN "abspath"  with  RUN RL.Path("abspath")
	$replacements += $text =~  s/\s(RUN)\s+($runex)/ $1 RL\.Path\($2\)/g;
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

#Replace SCALL() with CALL "CDS180"
#Updates: $text - text to search and replace
#		  $replacements - number of replacements made
sub do_scall {
    #Replace  SCALL("! cmd" with  SCALL("cmd"
	$replacements += $text =~  s/"!\s(mv|ls) /"$1 /g;
	#Replace  lineno VAR=SCALL(stringexp)  with  lineno CALL "CDS180",stringexp,"ND",VAR
	$replacements += $text =~  s/(^[0-9]+)\s+(\w*)=SCALL\(($scallex)\)/$1 CALL "CDS180",$3,"ND",$2/g;
	#Replace  LET VAR=SCALL(stringexp)  with  CALL "CDS180",stringexp,"ND",VAR
	$replacements += $text =~  s/\s+LET\s+(\w*)=SCALL\(($scallex)\)/ CALL "CDS180",$2,"ND",$1/g;
	#Replace  LET VAR=SCALL(stringexp,ERR=linelabel)  with  CALL "CDS180",ERR=linelabel,stringexp,"ND",VAR
	$replacements += $text =~  s/\s+LET\s+(\w*)=SCALL\(($scallex),ERR=(\w*)\)/ CALL "CDS180",ERR=$3,$2,"ND",$1/g;
	#Replace  ,VAR=SCALL(stringexp)  with  ;CALL "CDS180",stringexp,"ND",VAR
	$replacements += $text =~  s/,\s*(\w*)=SCALL\(($scallex)\)\s*$/; CALL "CDS180",$2,"ND",$1/g;
	#Replace  ,VAR=SCALL(stringexp);  with  ;CALL "CDS180",stringexp,"ND",VAR;
	$replacements += $text =~  s/,\s*(\w*)=SCALL\(($scallex)\)\s*;/; CALL "CDS180",$2,"ND",$1;/g;
	#Replace  ,VAR=SCALL(stringexp),  with  ;CALL "CDS180",stringexp,"ND",VAR; LET 
	$replacements += $text =~  s/,\s*(\w*)=SCALL\(($scallex)\)\s*,/; CALL "CDS180",$2,"ND",$1; LET /g;
	#Replace  ;VAR=SCALL(stringexp)  with  ;CALL "CDS180",stringexp,"ND",VAR
	$replacements += $text =~  s/;\s*(\w*)=SCALL\(($scallex)\)/; CALL "CDS180",$2,"ND",$1/g;
	#Replace  IF VAR=SCALL(stringexp)  with  CALL "CDS180",stringexp,"ND",VAR
	$replacements += $text =~  s/\s+IF\s+SCALL\(($scallex)\)/ LET SCALL_RESULT=CALL "CDS180",$2,"ND",$1; IF SCALL_RESULT /g;
	push @unreplaced, $text =~ /(SCALL\([^\)]*\))/g;
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
	#Regular Expression for absolute path filespec after RUN
	$runex = '"\/[^; ]*'; #Literal String beginning with forward slash plus any non-semicolon
	#Regular Expression for absolute path filespec after CALL
	$callex = '"\/.*?"'; #Literal String beginning with forward slash
	#Regular Expression for absolute path NOT beginning with /rlbase/basis/pro5
	$nop5ex = '"\/(?!rlbase.basis.pro5).*?"'; 
	#Regular Expression for absolute path beginning with /rlbase/basis/pro5/
	$pro5ex = '"\/rlbase\/basis\/pro5\/'; 
	#Regular Expression for absolute path beginning with /*/CDI
	$smsex = '"\/\w+\/CDI\/'; 
	#Regular Expression for SCALL arguments
	$scallex = '".*?"'; #"string"
	$scallex .= '|".*?"\+[\w\.]*\$'; #"string"+var$
	$scallex .= '|".*?"\+[\w\.]*\$\+[\w\.]*\$'; #"string"+var$+var$
	$scallex .= '|".*?"\+[\w\.]*\$\+".*?"\+[\w\.]*\$\+".*?"'; #"string"+var$+"string"+var$+string$
	#$scallex .= '|".*?"\+\w+\([^\)\(]+\)'; #"string"+fnc() - Catches all expressions containing a function - Use with Caution
	$scallex .= '|[\w\.]*\$'; #var$
	$scallex .= '|[\w\.]*\$\+[\w\.]*\$'; #var$+var$
	$scallex .= '|[\w\.]*\$\(.*?\)'; #var$(expr)

}

#Write out changed file
sub write_file {
	print "filename=$filename\n" if $debug;
	my $outname = fileparse($filename);
	print "outname=$outname\n" if $debug;
	my $outspec = $write_dir . '/' . $outname;
	print "outspec=$outspec\n" if $debug;
	open(my $of, '>', $outspec) or die "Could not open file '$outname' $!";
	foreach (@prog_lines) {
		print $of "$_\n";
	}
	close $of;
}
