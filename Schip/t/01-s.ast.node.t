#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 9;
use Moose::Autobox;

BEGIN { use_ok('Schip::AST::Node'); }

my $two = Schip::AST::Num->new(value => 2);
ok($two, "can create num 'two'");

note("building the ast tree for (lambda (x) (+ 2 x))");

my $args = Schip::AST::List->new;
ok($args, "can create s.a.list for args");
$args->value->push(Schip::AST::Sym->new(value => 'x'));
is($args->value->length, 1, "args has 1 item");

my $body = Schip::AST::List->new;
ok($body, "can create s.a.list for body");
$body->value([
	Schip::AST::Sym->new(value => '+'),
	Schip::AST::Num->new(value => 2),
	Schip::AST::Sym->new(value => 'x'),
]);
is($body->value->length, 3, "body has 3 items");

my $lambda = Schip::AST::List->new;
ok($lambda, "can create s.a.list for lambda");
$lambda->value->push(Schip::AST::Sym->new(value => 'lambda'));
$lambda->value->push($args);
$lambda->value->push($body);
is($lambda->value->length, 3, "lambda has 3 items");

is($lambda->value->[2]->value->[2]->value, 'x', "can create down tree correctly");

is($lambda->to_string,
	"(lambda (x) (+ 2 x))",
	"lambda deparses to correct representation");
