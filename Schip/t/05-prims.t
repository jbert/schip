#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 130;
use Moose::Autobox;

use Schip::Evaluator;
use lib 't';
require Testutil;

run_main_tests();
exit 0;

sub run_main_tests {
	test_not();
	test_plus();
	test_list();
	test_cons_car_cdr();
	test_equals();
}

sub test_not {
	my @test_cases = (
		'(not 1)'						=> 0,
		'(not 0)'						=> 1,
		'(not (= 1 1))'					=> 0,
		'(not (= 1 0))'					=> 1,
	);

	run_test_cases("not", @test_cases);
}

sub test_equals {
	my @test_cases = (
		'(=)'						=> undef,
		'(= 1)'						=> undef,

		'(= 1 2)'					=> 0,

		'(= 0 0)'					=> 1,
		'(= 0 1)'					=> 0,
		'(= 1 0)'					=> 0,
		'(= 1 1)'					=> 1,

		'(= 0 0 0)'					=> 1,
		'(= 1 0 0)'					=> 0,
		'(= 0 1 0)'					=> 0,
		'(= 0 0 1)'					=> 0,
		'(= 1 1 0)'					=> 0,
		'(= 0 1 1)'					=> 0,
		'(= 1 0 1)'					=> 0,
		'(= 1 1 1)'					=> 1,
		'(= 1 1 1)'					=> 1,

#		'(= "a" "b")'				=> 0,
#		'(= "a" "a")'				=> 1,
#		'(= "a" 1)'					=> 0,
#		'(= "a" 65)'				=> 0,
	);
	run_test_cases('equals', @test_cases);
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
		# Consing with '() makes a list
		"(cons 1 '())"			=> {deparse => '(cons 1 (quote ()))', value => [1]},
		"(cons 1 (cons 2 '()))"	=> {deparse => '(cons 1 (cons 2 (quote ())))', value => [1, 2]},
		# Consing otherwise makes a pair
		'(cons 1 2)'			=> Schip::AST::Pair->new(Schip::AST::Num->new(1), Schip::AST::Num->new(2)),

		# car and cdr of pair
		'(car (cons 1 2))'			=> 1,
		'(cdr (cons 1 2))'			=> 2,

		# car and cdr of a list
		"(car (list 1))"			=> 1,
		"(cdr (list 1))"			=> [],
		# and a bigger list
		"(car (list 1 2))"			=> 1,
		"(cdr (list 1 2))"			=> [2],
		"(car (cdr (list 1 2)))"	=> 2,
		"(cdr (cdr (list 1 2)))"	=> [],

		# Extending list doesn't change it
		'(begin
			(define a (list 1 2 3))
		 	(define b (cons "b" a))
			a)'						=> [1, 2, 3],

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

