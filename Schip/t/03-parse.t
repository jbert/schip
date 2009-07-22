#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 79;
use Moose::Autobox;

BEGIN { use_ok('Schip::Parser'); }

my $parser = Schip::Parser->new;

my $tree = $parser->parse("");
ok(!$tree, "can't make a tree from nowt (parse to empty list?)");

$tree = $parser->parse(")(");
ok(!$tree, "can't parse invalid (todo-line number of failure etc)");

note "parse string";
my $code = '(display "hello, world")';
$tree = $parser->parse($code);
ok($tree, "can parse code");
isa_ok($tree, 'Schip::AST::Node', "tree is-a node");
isa_ok($tree, 'Schip::AST::List', "tree is-a list");
is($tree->value->length, 2, "root has 2 children");

isa_ok($tree->value->[0], 'Schip::AST::Sym', "display -> symbol");
is($tree->value->[0]->value, "display", "with correct value");

isa_ok($tree->value->[1], 'Schip::AST::Str', "string -> str");
is($tree->value->[1]->value, 'hello, world', "with correct value");


note "parse string with quotes";
$code = '(display "hello, \\"world\\"")';
$tree = $parser->parse($code);
ok($tree, "can parse code");
isa_ok($tree, 'Schip::AST::Node', "tree is-a node");
isa_ok($tree, 'Schip::AST::List', "tree is-a list");
is($tree->value->length, 2, "root has 2 children");

isa_ok($tree->value->[0], 'Schip::AST::Sym', "display -> symbol");
is($tree->value->[0]->value, "display", "with correct value");

isa_ok($tree->value->[1], 'Schip::AST::Str', "string -> str");
is($tree->value->[1]->value, 'hello, \"world\"', "with correct value");


my %atom_type = (
	"+"					=> 'Sym',
	"1024",				=> 'Num',
	"-10",				=> 'Num',
	"1.0",				=> 'Num',
	"-1.0",				=> 'Num',
	'hello'				=> 'Sym',
	'"hello, world"'	=> 'Str',
	"0",				=> 'Num',
);
foreach my $atom_string (keys %atom_type) {
	$tree = $parser->parse($atom_string);
	ok($tree, "can parse $atom_string");
	my $expected_type = $atom_type{$atom_string};
	isa_ok($tree, "Schip::AST::$expected_type", "tree is-a expected type");
}

note "parse a lambda expression";
$code = "(lambda (x) (+ 2 x))";
$tree = $parser->parse($code);
ok($tree, "can parse code");
isa_ok($tree, 'Schip::AST::Node', "tree is-a node");
isa_ok($tree, 'Schip::AST::List', "tree is-a list");
is($tree->value->length, 3, "root has 3 children");

isa_ok($tree->value->[0], 'Schip::AST::Sym', "lambda -> symbol");
is($tree->value->[0]->value, "lambda", "with correct value");

my $args = $tree->value->[1];
ok($args, "can extract args");
is($args->value->length, 1, "args has length 1");
is($args->value->[0]->value, "x", "with correct value");

my $body = $tree->value->[2];
ok($body, "can extract body");
is($body->value->length, 3, "body has length 3");
is($body->value->[0]->value, "+", "with correct value");
isa_ok($body->value->[0], 'Schip::AST::Sym', "+ -> symbol");
is($body->value->[1]->value, "2", "with correct value");
isa_ok($body->value->[1], 'Schip::AST::Num', "2 -> symbol");
is($body->value->[2]->value, "x", "with correct value");
isa_ok($body->value->[2], 'Schip::AST::Sym', "x -> symbol");
is($tree->deparse, $code, "deparse correctly");

note "parse the empty list";
$code = "()";
$tree = $parser->parse($code);
ok($tree, "can parse code");
isa_ok($tree, 'Schip::AST::Node', "tree is-a node");
isa_ok($tree, 'Schip::AST::List', "tree is-a list");
is($tree->value->length, 0, "root has 0 children");

note "parse the quoted empty list";
$code = "'()";
$tree = $parser->parse($code);
ok($tree, "can parse code");
isa_ok($tree, 'Schip::AST::Node', "tree is-a node");
isa_ok($tree, 'Schip::AST::List', "tree is-a list");
is($tree->value->length, 2, "root has 2 children");
isa_ok($tree->value->[0], 'Schip::AST::Sym', "first child is a sym");
is($tree->value->[0]->value, 'quote', "first val quote");
isa_ok($tree->value->[1], 'Schip::AST::List', "second val list");
is($tree->value->[1]->value->length, 0, "which is empty");

note "parse a list with empty string";
$code = '("")';
$tree = $parser->parse($code);
ok($tree, "can parse code");
isa_ok($tree, 'Schip::AST::Node', "tree is-a node");
isa_ok($tree, 'Schip::AST::List', "tree is-a list");
is($tree->value->length, 1, "root has 0 children");

isa_ok($tree->value->[0], 'Schip::AST::Str', "found string");
is($tree->value->[0]->value, "", "and it's empty");

$code = "'(a b c)";
$tree = $parser->parse($code);
ok($tree, "can parse quoted list");
isa_ok($tree, 'Schip::AST::List', "tree is-a list");
is($tree->value->length, 2, " has 2 children");

isa_ok($tree->value->[0], 'Schip::AST::Sym', "first child is a sym");
is($tree->value->[0]->value, 'quote', "first child is a sym called quote");

isa_ok($tree->value->[1], 'Schip::AST::List', "second child is a list");
is($tree->value->[1]->value->length, 3, "second child has 3 elements");

$code = "(a '(b c))";
$tree = $parser->parse($code);
is($tree->deparse, "(a (quote (b c)))", "deparse correctly");

$code = <<"EOC";
;; This is some code
(a b c)		; with comments
EOC
$tree = $parser->parse($code);
is($tree->deparse, "(a b c)", "deparse has no comments");

$code = '(display "semicolon here -> ; <- which isnt a comment")';
$tree = $parser->parse($code);
is($tree->deparse, $code, "deparse doesn't have comments");
