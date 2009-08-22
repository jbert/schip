#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 25;
use Moose::Autobox;

use Schip::Evaluator;
use lib 't';
require Testutil;

run_main_tests();
exit 0;

sub run_main_tests {
	test_qq_with_nowt();
}

sub test_qq_with_nowt {
	my @test_cases = (
		"(quasiquote 0)"						=> 0,
		"(quasiquote ())"						=> [],
		"(quasiquote (+ 1 2))"					=> ['+', 1, 2],
		"(quasiquote (+ (unquote (+ 1 3)) 2))"	=> ['+', 4, 2],
	);

	run_test_cases("test quasiquote", @test_cases);
}
