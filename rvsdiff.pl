#!/usr/bin/perl

#Split diff file into discrete patch files
#Similar to the Linux patch command, but operates on BBx Line Numbers
#Only applies changes to matching lines

use Getopt::Std;	#Perl GetOpts Package

getopts("v", \%opts) || die ;
$verbose = defined $opts{v};

if (scalar @ARGV != 2) {
	print "Clean Git diff file and reverse direction of changes\n";
	print "Usage: $0 diff-file rvs-file\n";
	print "Options: -v  Verbose\n";
	print "\n";
	exit;
}


$diffFileName = $ARGV[0];
$rvsFileName = $ARGV[1];
$vbs = STDOUT;

open $diffFile, "$diffFileName" or die "Error $! opening file $diffFileName\n";
open($rvsFile, '>', $rvsFileName) or die "Error $! opening file $rvsFileName\n";

print $vbs "Reading $diffFileName\n" if $verbose;
print $vbs "Writing $rvsFileName\n" if $verbose;

while ($patchLine = readline $diffFile) {
	print $vbs "lastPfx=$lastPfx\n" if $verbose;
	chomp($patchLine);
	
	if ($lastPfx eq "+" or $lastpfx eq "-") {
		unless ($patchLine =~ /^[+-]/) {
			#Swap + and - lines
			foreach (@plusLines) {print $rvsFile "-$_";};
			undef @plusLines;
			foreach (@minusLines) {print $rvsFile "+$_";};
			undef @minusLines;
		}
	} elsif ($lastPfx eq "diff") {
		die("No 'index' after 'diff' for $diffName\n") unless $patchLine =~ /^index/;
		$lastPfx = "index";
		print $vbs "Skipping index line\n" if $verbose;
		next;
	} elsif ($lastPfx eq "index") {
		die("No '---' after 'diff' for $diffName\n") unless $patchLine =~ /^--- /;
		$minusName = substr $patchLine, 4; 
		$minusName =~ s/ [ab]\// /g;
		$lastPfx = "---";
		next;
	} elsif ($lastPfx eq "---") {
		die("No '+++' after 'diff' for $diffName\n") unless $patchLine =~ /^\+\+\+ /;
		$plusName = substr $patchLine, 4;
		$plusName =~ s/ [ab]\// /g;
		$lastPfx = "+++";
		next;
	} elsif ($lastPfx eq "+++") {
		#Swap diff'ed files names (for added, removed, or renamed programs)
		print $rvsFile "--- $plusName\n";
		print $rvsFile "+++ $minusName\n";
		$lastPfx = "";
	}
	
	if ($patchLine =~ /^\+/) {
		push @plusLines, substr $patchLine, 1;
		$lastPfx = "+";
		next;
	} elsif ($patchLine =~ /^-/) {
		push @minusLines, substr $patchLine, 1;
		$lastPfx = "-";
		next;
	} elsif ($patchLine =~ /^diff/) {
		$diffName = getDiffName($patchLine);
		print $vbs "Processing diff for $diffName\n" if $verbose;
		#Strip leading a/ or b/ from front of filename
		$patchLine =~ s/ [ab]\// /g;
		$lastPfx = "diff";
	} elsif ($patchLine =~ /^\@\@/) {
		#Swap line number ranges for + and -
		$patchLine =~ s/(^\@\@ -)([\d,]+)( \+)([\d,]+)( \@\@)/$1$4$3$2$5/;
		$lastPfx = "@@";
	} else {
		die("Unexpected line: $patchLine\n");
	}
	print $rvsFile "$patchLine\n";
}

sub getDiffName {
	my @matches = $_[0] =~ /( b\/)(.*)/;
	my $diffName = $matches[1];
	return "$diffName";
}
