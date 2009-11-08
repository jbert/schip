#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 270;
use Moose::Autobox;

BEGIN { use_ok('Schip::Evaluator'); }
use Schip::AST::Node;
use Schip::Parser;
use lib 't';
require Testutil;

run_main_tests();
exit 0;

sub run_main_tests {
	test_define();
	test_lambda();
	test_dotted_lambda();
	test_pairs();
	test_if();
    test_atoms();
    test_two_plus_two();
	test_quote();
	test_begin();
	test_error();
	test_closure();
}

sub test_pairs {
	my @test_cases = (
		"(quote (1 . 2))"	    => {1 => 2},
		"(quote (1  2 . 3))"	=> {1 => {2 => 3}},
		"(quote (1 . (2 3)))"	=> {
            deparse =>  "(quote (1 2 3))",
            value   =>  [1, 2, 3],
        },
	);

	run_test_cases("test pairs", @test_cases);
}

sub test_quote {
	my @test_cases = (
		"()"				=> undef,
		"(quote 0)"			=> 0,
		"(quote 1)"			=> 1,
		"(quote 5)"			=> 5,
		'(quote "hello")'	=> "hello",
		"(quote ())"		=> [],
		"(1 2 3)"			=> undef,
		"(quote (1 2 3))"	=> [1, 2, 3],
	);

	run_test_cases("test quote", @test_cases);
}

sub test_error {
	my @test_cases = (
		# TODO: test returned error string
		"(error)"			=> undef,
		"(error \"bob\")"	=> undef,
		"(begin
			(error \"bob\")
			5)"				=> undef,

		"(/ 1 1)"		=> "1",
		"(/ 2 1)"		=> "2",
		"(/ 2 0)"		=> undef,
		"(/ 1 10)"		=> "1/10",
	);
	run_test_cases("test error", @test_cases);
}

sub test_begin {
	my @test_cases = (
		# Test begin
		"(begin 1)"		=> "1",
		"(begin 1 2)"	=> "2",
		"(begin 0 1 2)"	=> "2",
	);
	run_test_cases("test begin", @test_cases);
}

sub test_define {
	my @test_cases = (
		# Basic test of define (define returns defined val)

		"(begin
			(define (f x) x)
			(f 1))"     => 1,
		"(define x 2)"	=> "2",
		"(define x (+ 2 2))"	=> "4",
		"(begin
			(define x (+ 2 2))
			x)"			=> "4",
		"(begin
			(define x (+ 2 2))
			(define y (+ 3 4))
			(define z (+ x y))
			z)"			=> "11",
		"(begin
			(define (f x . y) x)
			(f 1))"     => 1,
		"(begin
			(define (f x . y) x)
			(f 1 2))"   => 1,
		"(begin
			(define (f x . y) x)
			(f 1 2 3))" => 1,

		"(begin
			(define (f x . y) y)
			(f 1))"     => [],
		"(begin
			(define (f x . y) y)
			(f 1 2))"   => 2,
		"(begin
			(define (f x . y) y)
			(f 1 2 3))" => [2, 3],
	);
	run_test_cases("test define", @test_cases);
}

sub test_dotted_lambda {
	my @test_cases = (
		"((lambda (x y . z) z) 0)"	        => undef,
		"((lambda (x y . z) z))"	        => undef,
		"((lambda (x . y) x) 0)"		    => 0,
		"((lambda (x y . z) x) 0 1)"	    => 0,
		"((lambda (x y . z) y) 0 1)"	    => 1,
		"((lambda (x y . z) z) 0 1 2)"	    => [2],
		"((lambda (x y . z) z) 0 1 2 3)"	=> [2, 3],
    );

    my $code = "((lambda (first second . rest) (list first second rest)) 1 2 3 4 5 6 7 8 9)";
    push @test_cases, $code => [1, 2, [3, 4, 5, 6, 7, 8, 9]];
	run_test_cases("test dotted lambda", @test_cases);
}

sub test_lambda {
	my @test_cases = (
		# Test lambda
		"((lambda (x) x) 0)"			=> 0,
		"((lambda (x) x) 1)"			=> 1,
		"((lambda (x) x) 2)"			=> 2,
		'((lambda (x) x) "hello, world")'			=> "hello, world",
		"((lambda (x) (+ 2 x)) 2)"		=> 4,
		"((lambda (x) (+ x x)) 3)"		=> 6,
		"((lambda (x y) (+ x y)) 3 4)"	=> 7,
		"((lambda (x y) y) 3 4)"	    => 4,
		"((lambda (x y) x) 3 4)"	    => 3,
		"((lambda (x y) x y) 3 4)"	    => 4,
		"((lambda (x y) (+ x 1) (+ y 2)) 3 4)"	    => 6,
	);
	run_test_cases("test lambda", @test_cases);
}

sub test_closure {

	my @test_cases = (
		# TODO - do we want implicit begin over multiple forms?
		# TODO - what semantics do we want for scheme top-level
		# define and internal define?
		"(begin
			(define x 2)
			(begin 0 x))"				=> 2,
		"(begin
			(define x 2)
			(+ 3 x))"					=> 5,
		"(begin
			(define double (lambda (x) (+ x x)))
			(double 3))"				=> 6,

		# Test more complex lambda/define usage
		"(begin
			(define make-adder
				(lambda (n)
					(lambda (x) (+ n x))))
			(define add-twoer
				(make-adder 2))
			(add-twoer 7))"				=> 9,
	);
	run_test_cases("test closure", @test_cases);
}

sub test_if {
	my @test_cases = (
		# if
		"(error)"						=> undef,
		"(if 0 1 2)"					=> 2,
		"(if 1 1 2)"					=> 1,

		# Perl semantics here?
		'(if "foo" 1 2)'				=> 1,
		'(if "0" 1 2)'					=> 1,
		'(if "" 1 2)'					=> 2,
		"(if (quote ()) 1 2)"			=> 2,
		# TODO: add empty list?
		# TODO: add #t and #f bool type


		"(if 0 (+ 2 3) (+ 4 5))"		=> 9,

		'(if (error) 1 2)'				=> undef,
		"(if 0 (error) 2)"				=> 2,
		"(if 1 (error) 2)"				=> undef,
		
	);
	run_test_cases("test if", @test_cases);
}

sub test_atoms {
	my $evaluator = Schip::Evaluator->new;
	my @self_evaluating_atoms = (
		Schip::AST::Num->new(1),
		Schip::AST::Num->new(0),
		Schip::AST::Num->new(10),
		Schip::AST::Str->new(""),
		Schip::AST::Str->new("hello"),
	);
	foreach my $atom (@self_evaluating_atoms) {
		my $result = $evaluator->evaluate_forms($atom);
		isa_ok($result, ref $atom, "result is same type as atom: "
			. $atom->value);
		is($result->value, $atom->value, "result has same value as atom");
	}
}

sub test_two_plus_two {
	my $two_plus_two_form = make_two_plus_two();
	my $evaluator = Schip::Evaluator->new;
	ok($evaluator, "can create evaluator");
	my $result = $evaluator->evaluate_forms($two_plus_two_form);
	ok($result, "can get value back");
	isa_ok($result, 'Schip::AST::Atom', "get back an atomic value");
	isa_ok($result, 'Schip::AST::Num', "get back a numeric value");
	is($result->value, 4, "2+2 = 4!");
}

sub make_two_plus_two {
	my $form = Schip::AST::List->new;
	$form->unshift(
			Schip::AST::Sym->new('+'),
			Schip::AST::Num->new(2),
			Schip::AST::Num->new(2),
			);

	return $form;
}
