#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 55;
use Moose::Autobox;

BEGIN { use_ok('Schip::Evaluator'); }
use Schip::AST::Node;
use Schip::Parser;

test_atoms();
test_two_plus_two();
main_tests();
exit 0;

sub main_tests {
	my @test_cases = (
		# Variations on a theme
		"0"				=> "0",
		"2"				=> "2",
		"(+ 1 2)"		=> "3",
		"(+ 1 2 3)"		=> "6",
		"(+ -1 1)"		=> "0",
		"(+ -1 1)"		=> "0",

		# Test begin
		"(begin 1)"		=> "1",
		"(begin 1 2)"	=> "2",
		"(begin 0 1 2)"	=> "2",

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

		# Test lambda
#		"((lambda (x) (+ 2 x)) 2)",

#		"(define x 2)\n(begin 0 x)"		=> 2,
#		"(define x 2)\n(+ 3 x)"			=> 5,
	);

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
		ok($result, "form evaluated ok");
		note("failed with errstr: " . $evaluator->errstr) if !$result;
		is($result->value, $expected, "form [$code] evaluates to expected val");
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
