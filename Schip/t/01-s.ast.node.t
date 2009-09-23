#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 33;

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
	Schip::AST::Sym->new('+'),
	Schip::AST::Num->new(2),
	Schip::AST::Sym->new('x'),
);
is($body->length, 3, "body now has 3 items");

my $lambda = Schip::AST::List->new;
ok($lambda, "can create empty s.a.list for lambda");
$lambda->push(Schip::AST::Sym->new('lambda'));
$lambda->push($args);
$lambda->push($body);
is($lambda->length, 3, "lambda has 3 items");

is($lambda->nth(2)->nth(2), 'x', "can create down tree correctly");

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

my $num_nums = 10;
my $nums = Schip::AST::List->new(map { Schip::AST::Num->new($_) } (1..$num_nums));
ok($nums, "can create list of nums");
is($nums->length, $num_nums, "list has length $num_nums");
is($nums->nth(0), 1, "list starts with 1");
is($nums->nth(1), 2, "cadr list is 2");

my $from_2 = $nums->cdr;
is($from_2->length, $num_nums-1, "cdr has length " . ($num_nums-1));
is($from_2->nth(0), 2, "cdr starts with 2");

$from_2->car(5);
is($from_2->length, $num_nums-1, "cdr has length " . ($num_nums-1));
is($from_2->nth(0), 5, "cdr starts with 2");

is($nums->nth(0), 1, "car list is 1");
is($nums->nth(1), 2, "cadr list is 2");
is($nums->length, $num_nums, "list still has length $num_nums");
