#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

my ($egdir)		= grep { -e "$_/example.dir" }				qw(. ../eg eg);
unless ($egdir) {
	plan skip_all => "Can't find example dir";
	exit 0;
}

my $mzscheme	= `which mzscheme`;
unless ($mzscheme) {
	plan skip_all => "mzscheme not installed";
	exit 0;
}

my $binname		= 'schip';
my ($bintool)	= grep { -e $_ } map { "$_/$binname" }		qw(. ../bin bin);
unless ($bintool) {
	plan skip_all => "Can't find bintool";
	exit 0;
}

plan tests => 1;

foreach my $egfile (glob("$egdir/*.ss")) {
	note "Running example file $egfile";
	my $mzscheme_output = join('', `mzscheme -f $egfile`);
	my $bintool_output	= join('', `$bintool $egfile`);
	is($bintool_output, $mzscheme_output, "mzscheme gives same output as bintool");
}
