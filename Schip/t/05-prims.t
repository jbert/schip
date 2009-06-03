#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 40;
use Moose::Autobox;

use Schip::Evaluator;
require t::Testutil;

run_main_tests();
exit 0;

sub run_main_tests {
	test_plus();
	test_list();
#	test_cons_car_cdr();
}

sub test_list {
	my @test_cases = (
		'(list 1)'						=> [1],
		'(list)'						=> [],
		'(list 1 2)'					=> [1, 2],
		'(list 1 2 "hello, world")'		=> [1, 2, "hello, world"],
	);

	run_test_cases("list", @test_cases);
}

sub test_cons_car_cdr {
	my @test_cases = (
		"(cons 1 '())"			=> [1],
		"(cons 1 (cons 2 '()))"	=> [1, 2],
		'(cons 1 2)'			=> Schip::AST::Pair->new(value => [Schip::AST::Num->new(value => 1),
																   Schip::AST::Num->new(value => 1)]),

		# car and cdr of pair
		'(car (cons 1 2))'		=> 1,
		'(cdr (cons 1 2))'		=> 2,

		# car and cdr of a list
		"(car (cons 1 '()))"	=> 1,
		"(cdr (cons 1 '()))"	=> [],
		"(car (cons 1 (cons 2 '())))"	=> 1,
		"(cdr (cons 1 (cons 2 '())))"	=> [],

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

