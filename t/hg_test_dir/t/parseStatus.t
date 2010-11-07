#!/usr/bin/perl

use 5.006;
use strict;
use warnings;
use Test::More tests => 3;
use FindBin qw($Bin);
use lib ("$Bin/../");
use parseStatus;
use Data::Dumper;
my $dir;
open ( IF, "status.txt");

foreach my $statusLine (<IF>)
{
	my ($status, $filename) = split (/\s/,$statusLine);
	print "$status , $filename \n";
	my %node = (node=>$filename);
	 $dir = File::Basename::dirname($filename);
	if ( $dir =~ /\// ) {print "Has Sub Dir\n" }
	print $dir."\n";
}


my @branch = qw (dir1 dir2 file3);
my @branch2 = qw (dir1 dir2 file4 );

my %result = createBranch(@branch);
print Dumper(\%result);
my %result = createBranch(@branch2);
print Dumper(\%result);
is ( $result{root},'root','root' );
is ( $result{'dir1'}->[1],'root','Directory 1' );
is ( $result{'dir1/dir2'}->[1],'dir1','Directory 2' );