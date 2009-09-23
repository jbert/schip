#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 22;
use Moose::Autobox;

BEGIN { use_ok('Schip::AST::Node'); }

my $two = Schip::AST::Num->new(2);
ok($two, "can create num 'two'");

note("building the ast tree for (lambda (x) (+ 2 x))");

my $args = Schip::AST::List->new;
ok($args, "can create empty s.a.list for args");
$args->push(Schip::AST::Sym->new('x'));
is($args->length, 1, "now args has 1 item");

my $body = Schip::AST::List->new;
ok($body, "can create empty s.a.list for body");
$body->push(
	Schip::AST::Sym->new(value => '+'),
	Schip::AST::Num->new(value => 2),
	Schip::AST::Sym->new(value => 'x'),
);
is($body->length, 3, "body now has 3 items");

my $lambda = Schip::AST::List->new;
ok($lambda, "can create empty s.a.list for lambda");
$lambda->push(Schip::AST::Sym->new(value => 'lambda'));
$lambda->push($args);
$lambda->push($body);
is($lambda->length, 3, "lambda has 3 items");

is($lambda->[2]->[2], 'x', "can create down tree correctly");

is($lambda->deparse,
	"(lambda (x) (+ 2 x))",
	"lambda deparses to correct representation");

note("test string quoting");
my %test_cases = (
	"hi",						=> '"hi"',
	"hello, world"				=> '"hello, world"',
	'like "hello", world'		=> '"like \\"hello\\", world"',
	'this ->\\ is a slash'		=> '"this ->\\\\ is a slash"',
);

foreach my $test_str (keys %test_cases) {
	my $strNode = Schip::AST::Str->new($test_str);
	ok($strNode, "can create string node");
	is($strNode->value, $test_str, "which stashes correct value");
	is($strNode->deparse, $test_cases{$test_str}, "which stashes correct value");
}
