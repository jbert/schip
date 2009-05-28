#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 94;
use Moose::Autobox;

BEGIN { use_ok('Schip::Evaluator'); }
use Schip::AST::Node;
use Schip::Parser;

test_atoms();
test_two_plus_two();
run_main_tests();
exit 0;

sub run_main_tests {
	test_primitives();
	test_begin();
	test_define();
	test_lambda();
	test_closure();
#	test_if();
}

sub test_primitives {
	my @test_cases = (
		"0"				=> "0",
		"2"				=> "2",
		"(+ 1 2)"		=> "3",
		"(+ 1 2 3)"		=> "6",
		"(+ -1 1)"		=> "0",
		"(+ -1 1)"		=> "0",

		# TODO: test returned error string
		"(error)"			=> undef,
		"(error \"bob\")"	=> undef,
		"(begin
			(error \"bob\")
			5)"				=> undef,

#		"(/ 1 1)"		=> "1",
#		"(/ 2 1)"		=> "2",
#		"(/ 2 0)"		=> undef,
#		"(/ 1 10)"		=> "1/10",
	);
	run_test_cases("test plus", @test_cases);
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
	);
	run_test_cases("test define", @test_cases);
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
		"(/ 1 0)"						=> undef,
		"(if 0 1 2)"					=> 2,
		"(if 1 1 2)"					=> 1,
		"(if 0 1 2)"					=> 1,
		
#		"(define x 2)\n(begin 0 x)"		=> 2,
#		"(define x 2)\n(+ 3 x)"			=> 5,
	);
	run_test_cases("test if", @test_cases);
}

sub run_test_cases {
	my $diag = shift;
	my @test_cases = @_;

	note "=" x 5 . " " . $diag;

	my $parser = Schip::Parser->new;
	while (@test_cases) {
		my $code		= shift @test_cases;
		my $expected	= shift @test_cases;

		note("Checking $code");

		my $tree		= $parser->parse($code);
		my $deparse		= $tree->to_string;
		my $mungedCode  = $code;
		$mungedCode =~ s/\s+/ /g;
		is($deparse, $mungedCode, "parsed code deparses to same string");
		my $evaluator	= Schip::Evaluator->new;
		my $result		= $evaluator->evaluate_form($tree);
		if (defined $expected) {
			ok($result, "form evaluated ok");
			note("failed with errstr: " . $evaluator->errstr) if !$result;
			is($result->value, $expected, "form [$code] evaluates to expected val");
		}
		else {
			# TODO: check errstr, line # etc
			ok(!defined $result, "form returned undef");
		}
	}
}

sub test_atoms {
	my $evaluator = Schip::Evaluator->new;
	my @self_evalating_atoms = (
		Schip::AST::Num->new(value => 1),
		Schip::AST::Num->new(value => 0),
		Schip::AST::Num->new(value => 10),
		Schip::AST::Str->new(value => ""),
		Schip::AST::Str->new(value => "hello"),
	);
	foreach my $atom (@self_evalating_atoms) {
		my $result = $evaluator->evaluate_form($atom);
		isa_ok($result, ref $atom, "result is same type as atom: "
			. $atom->value);
		is($result->value, $atom->value, "result has same value as atom");
	}
}

sub test_two_plus_two {
	my $two_plus_two_form = make_two_plus_two();
	my $evaluator = Schip::Evaluator->new;
	ok($evaluator, "can create evaluator");
	my $result = $evaluator->evaluate_form($two_plus_two_form);
	ok($result, "can get value back");
	isa_ok($result, 'Schip::AST::Atom', "get back an atomic value");
	isa_ok($result, 'Schip::AST::Num', "get back a numeric value");
	is($result->value, 4, "2+2 = 4!");
}

sub make_two_plus_two {
	my $form = Schip::AST::List->new;
	$form->value([
			Schip::AST::Sym->new(value => '+'),
			Schip::AST::Num->new(value => 2),
			Schip::AST::Num->new(value => 2),
			]);

	return $form;
}
