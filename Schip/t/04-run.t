#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 24;
use Moose::Autobox;

BEGIN { use_ok('Schip::Evaluator'); }
use Schip::AST::Node;

test_atoms();
test_two_plus_two();

sub test_atoms {
	my $evaluator = Schip::Evaluator->new;
	my @self_evalating_atoms = (
		Schip::AST::Num->new(value => 1),
		Schip::AST::Num->new(value => 0),
		Schip::AST::Num->new(value => 10),
		Schip::AST::Str->new(value => ""),
		Schip::AST::Str->new(value => "hello"),
		Schip::AST::Sym->new(value => '+'),
		Schip::AST::Sym->new(value => 'lambda'),
		Schip::AST::Sym->new(value => 'begin'),
		Schip::AST::Sym->new(value => 'unrecognised-symbol'),
	);
	foreach my $atom (@self_evalating_atoms) {
		my $result = $evaluator->evaluate_form($atom);
		isa_ok($result, ref $atom, "result is same type as atom: " . ref $atom);
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
