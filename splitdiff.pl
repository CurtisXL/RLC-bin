#!/usr/bin/perl

#Split diff file into discrete patch files
#Similar to the Linux patch command, but operates on BBx Line Numbers
#Only applies changes to matching lines

use File::Basename;
use File::Path qw(make_path);
use Getopt::Std;	#Perl GetOpts Package

getopts("d:v", \%opts) || die ;
$directory = $opts{d};
$verbose = defined $opts{v};

if (scalar @ARGV != 1) {
	print "RLC Patch File Split Utility\n";
	print "Usage: $0 YYMMDD\n";
	print "Options: -d directory (default=out/legacy/)\n";
	print "\n";
	print "Expects file named patch-YYMMDD in specified or default directory\n";
	exit;
}

$diffDirectory = $directory || "out/legacy";

$patchDate = $ARGV[0];

$patchDirectory = "$diffDirectory/patch-$patchDate/";
$diffFileName = "patch-$patchDate.diff";

print "Creating directory $patchDirectory\n" if $verbose;
make_path $patchDirectory || die "Error creating directory $patchDirectory";

open $diffFile, "$diffDirectory/$diffFileName" or die "Error $! opening file $diffFileName\n";
print "Reading $diffFileName\n" if $verbose;
print "Writing to directory $patchDirectory\n" if $verbose;
while ($patchLine = readline $diffFile) {
	chomp($patchLine);
	if ($patchLine =~ /^diff/) {
		close $patchFile;
		$patchFileName = getFileName($patchLine);
		make_path $patchDirectory . dirname($patchFileName);
		$patchFileSpec = "$patchDirectory/$patchFileName";
		open($patchFile, '>', $patchFileSpec) or die "Error $! opening file $patchFileSpec\n";
		print "Writing $patchFileName\n" if $verbose;
		$patchLine =~ s/ [ab]\// /g;
		print $patchFile "$patchLine\n";
		next;
	}
	#next if $patchLine =~ /^index \w+\.\.\w+ [0-9]+$/;
	$patchLine =~ s/ [ab]\// /g if $patchLine =~ /^(\+\+\+|\-\-\-)/;
	print $patchFile "$patchLine\n";
}

sub getFileName {
	my @matches = $_[0] =~ /( b\/)(.*)/;
	my $fileName = $matches[1];
	#$fileName =~ s/\//_/g;
	return "$fileName.diff";
}

