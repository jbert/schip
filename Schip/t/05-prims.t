#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 20;
use Moose::Autobox;

use Schip::Evaluator;
require t::Testutil;

run_main_tests();
exit 0;

sub run_main_tests {
	test_plus();
	test_cons_car_cdr();
}

sub test_cons_car_cdr {
	my @test_cases = (
		'(car (cons 1 2))'		=> 1,
		'(cdr (cons 1 2))'		=> 1,
	);

	run_test_cases("cons car cdr", @test_cases);
}

sub test_plus {
	my @test_cases = (
		"0"				=> "0",
		"2"				=> "2",
		"(+ 1 2)"		=> "3",
		"(+ 1 2 3)"		=> "6",
		"(+ -1 1)"		=> "0",
		"(+ -1 1)"		=> "0",
	);
	run_test_cases("test plus", @test_cases);
}

