#!usr/bin/perl
use strict;
use warnings;
use Test::More tests => 118;
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
is($tree->length, 2, "root has 2 children");

isa_ok($tree->nth(0), 'Schip::AST::Sym', "display -> symbol");
is($tree->nth(0), "display", "with correct value");

isa_ok($tree->nth(1), 'Schip::AST::Str', "string -> str");
is($tree->nth(1), 'hello, world', "with correct value");


note "parse string with quotes";
$code = '(display "hello, \\"world\\"")';
$tree = $parser->parse($code);
ok($tree, "can parse code");
isa_ok($tree, 'Schip::AST::Node', "tree is-a node");
isa_ok($tree, 'Schip::AST::List', "tree is-a list");
is($tree->length, 2, "root has 2 children");

isa_ok($tree->nth(0), 'Schip::AST::Sym', "display -> symbol");
is($tree->nth(0), "display", "with correct value");

isa_ok($tree->nth(1), 'Schip::AST::Str', "string -> str");
is($tree->nth(1), 'hello, \"world\"', "with correct value");


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
	ok(defined $tree, "can parse $atom_string");
	my $expected_type = $atom_type{$atom_string};
	isa_ok($tree, "Schip::AST::$expected_type", "tree is-a expected type");
}

note "parse a lambda expression";
$code = "(lambda (x) (+ 2 x))";
$tree = $parser->parse($code);
ok($tree, "can parse code");
isa_ok($tree, 'Schip::AST::Node', "tree is-a node");
isa_ok($tree, 'Schip::AST::List', "tree is-a list");
is($tree->length, 3, "root has 3 children");

isa_ok($tree->nth(0), 'Schip::AST::Sym', "lambda -> symbol");
is($tree->nth(0), "lambda", "with correct value");

my $args = $tree->nth(1);
ok($args, "can extract args");
is($args->length, 1, "args has length 1");
is($args->nth(0), "x", "with correct value");

my $body = $tree->nth(2);
ok($body, "can extract body");
is($body->length, 3, "body has length 3");
is($body->nth(0), "+", "with correct value");
isa_ok($body->nth(0), 'Schip::AST::Sym', "+ -> symbol");
is($body->nth(1), "2", "with correct value");
isa_ok($body->nth(1), 'Schip::AST::Num', "2 -> symbol");
is($body->nth(2), "x", "with correct value");
isa_ok($body->nth(2), 'Schip::AST::Sym', "x -> symbol");
is($tree->deparse, $code, "deparse correctly");

note "parse the empty list";
$code = "()";
$tree = $parser->parse($code);
ok($tree, "can parse code");
isa_ok($tree, 'Schip::AST::Node', "tree is-a node");
isa_ok($tree, 'Schip::AST::List', "tree is-a list");
is($tree->length, 0, "root has 0 children");

note "parse the quoted empty list";
$code = "'()";
$tree = $parser->parse($code);
ok($tree, "can parse code");
isa_ok($tree, 'Schip::AST::Node', "tree is-a node");
isa_ok($tree, 'Schip::AST::List', "tree is-a list");
is($tree->length, 2, "root has 2 children");
isa_ok($tree->nth(0), 'Schip::AST::Sym', "first child is a sym");
is($tree->nth(0), 'quote', "first val quote");
isa_ok($tree->nth(1), 'Schip::AST::List', "second val list");
is($tree->nth(1)->length, 0, "which is empty");

note "parse a list with empty string";
$code = '("")';
$tree = $parser->parse($code);
ok($tree, "can parse code");
isa_ok($tree, 'Schip::AST::Node', "tree is-a node");
isa_ok($tree, 'Schip::AST::List', "tree is-a list");
is($tree->length, 1, "root has 0 children");

isa_ok($tree->nth(0), 'Schip::AST::Str', "found string");
is($tree->nth(0), "", "and it's empty");

$code = "'(a b c)";
$tree = $parser->parse($code);
ok($tree, "can parse quoted list");
isa_ok($tree, 'Schip::AST::List', "tree is-a list");
is($tree->length, 2, " has 2 children");

isa_ok($tree->nth(0), 'Schip::AST::Sym', "first child is a sym");
is($tree->nth(0), 'quote', "first child is a sym called quote");

isa_ok($tree->nth(1), 'Schip::AST::List', "second child is a list");
is($tree->nth(1)->length, 3, "second child has 3 elements");

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

$code = '`(a b c)';
$tree = $parser->parse($code);
ok($tree, "can parse quasiquoted list");
isa_ok($tree, 'Schip::AST::List', "tree is-a list");
is($tree->length, 2, " has 2 children");

isa_ok($tree->nth(0), 'Schip::AST::Sym', "first child is a sym");
is($tree->nth(0), 'quasiquote', "first child is a sym called quasiquote");

isa_ok($tree->nth(1), 'Schip::AST::List', "second child is a list");
is($tree->nth(1)->length, 3, "second child has 3 elements");


$code = "`(a ,b ,@(cdr '(1 2 3)))";
$tree = $parser->parse($code);
ok($tree, "can parse complex qq list");
isa_ok($tree, 'Schip::AST::List', "tree is-a list");
is($tree->length, 2, " has 2 children");

isa_ok($tree->nth(0), 'Schip::AST::Sym', "first child is a sym");
is($tree->nth(0), 'quasiquote', "first child is a sym called quasiquote");

isa_ok($tree->nth(1), 'Schip::AST::List', "second child is a list");
is($tree->nth(1)->length, 3, "second child has 3 elements");

isa_ok($tree->nth(1)->nth(1), 'Schip::AST::List', "can find list where we're expecting comma");
is($tree->nth(1)->nth(1)->length, 2, "comma list has 2 elts");
isa_ok($tree->nth(1)->nth(1)->nth(0), 'Schip::AST::Sym', "2 elt list begins with symbol");
is($tree->nth(1)->nth(1)->nth(0), 'unquote', ", becomes 'unquote' symbol");

isa_ok($tree->nth(1)->nth(2), 'Schip::AST::List', "can find list where we're expecting comma-at");
is($tree->nth(1)->nth(2)->length, 2, "comma-at list has 2 elts");
isa_ok($tree->nth(1)->nth(2)->nth(0), 'Schip::AST::Sym', "2 elt list begins with symbol");
is($tree->nth(1)->nth(2)->nth(0), 'unquote-splicing', ", becomes 'unquote-splicing' symbol");



$code = "(a . b)";
$tree = $parser->parse($code);
ok($tree, "can parse dotted pair");
isa_ok($tree, 'Schip::AST::Pair', "tree is-a pair");

isa_ok($tree->car, 'Schip::AST::Sym', "first child is a sym");
is($tree->car, 'a', "first child is a sym called a");
isa_ok($tree->cdr, 'Schip::AST::Sym', "second child is a sym");
is($tree->cdr, 'b', "second child is a sym called b");




$code = "(a b . c)";
$tree = $parser->parse($code);
ok($tree, "can parse dotted list");
isa_ok($tree, 'Schip::AST::Pair', "tree is-a pair");

isa_ok($tree->car, 'Schip::AST::Sym', "first child is a sym");
is($tree->car, 'a', "first child is a sym called a");

isa_ok($tree->cdr, 'Schip::AST::Pair', "second child is a pair");
isa_ok($tree->cdr->car, 'Schip::AST::Sym', "with sym at car");
is($tree->cdr->car, 'b', "called b");
isa_ok($tree->cdr->cdr, 'Schip::AST::Sym', "and a sym at cdr");
is($tree->cdr->cdr, 'c', "called c");

exit 0;


