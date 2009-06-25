#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 12;

use_ok('Schip::Repl');

my @test_cases;

push @test_cases, {
	code => <<"EOC",
(define a 10)
(define f (lambda (x) (+ x x)))
(f 10)
EOC
	resp => {1 => "10", 3 => "20",}
};

push @test_cases, {
	code => <<"EOC",
(define a 10)
(define f (lambda (x) (+ x x)))
(f 10)
(f 10)
EOC
	resp => {1 => "10", 3 => "20", 4 => "20",}
};

foreach my $tc (@test_cases) {
	my $code				= $tc->{code};
	my $expected_response	= $tc->{resp};
	my $response = '';

	open(my $repl_infh, '<', \$code)			or die "can't open repl infh";
	open(my $repl_outfh, '>', \$response)		or die "can't open repl outfh";

	my $repl = Schip::Repl->new(in => $repl_infh, out => $repl_outfh);
	ok($repl, "can create a repl");

	ok($repl->run, "can run repl");
	ok($response, "have a response");
	my @bits = split(/^schip\s(\d+)> /m, $response);
	die "Oddness happened" unless $bits[0] =~ /SCHIP/;
	shift @bits;
	pop @bits;
	my %lines = @bits;
	chomp %lines;	# Just chomps values. cool.
#	print "L: $_ => $lines{$_}\n" for sort keys %lines;
	foreach my $line_number (sort keys %$expected_response) {
		is($lines{$line_number}, $expected_response->{$line_number}, "line $line_number matches");
	}
}
