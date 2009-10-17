use strict;
use warnings;
use Moose::Autobox;
use Schip::Parser;

sub run_test_cases {
	my $diag = shift;
	my @test_cases = @_;

	note "=" x 5 . " " . $diag;

	my $parser = Schip::Parser->new;
	while (@test_cases) {
		my $code		= shift @test_cases;
		my $expected	= shift @test_cases;

		my $expectedDeparse = $code;
		$expectedDeparse	=~ s/\s+/ /g;

		if (ref $expected && ref $expected eq 'HASH') {
			if (exists $expected->{value}) {
				$expectedDeparse = $expected->{deparse} if $expected->{deparse};
				$expected		 = $expected->{value};
			}
		}

		note("Checking $code");

		my @forms		= $parser->parse($code);
		is (scalar @forms, 1, "only one form");	# Extend...
		my $deparse		= $forms[0]->deparse;
		is($deparse, $expectedDeparse, "parsed code deparses to same string");
		my $evaluator	= Schip::Evaluator->new;
		my $got			= $evaluator->evaluate_forms(@forms);

		if (defined $expected) {
			ok(defined $got, "form evaluated ok");
			note("failed with errstr: " . $evaluator->errstr) if !defined $got;
			compare_ast_tree($got, $expected, "form [$code] evals to expected val");
		}
		else {
			ok(!defined $got, "form returned undef");
			return;
		}
	}
}

sub compare_ast_tree {
	my ($got, $expected, $str) = @_;

#warn "got: " . Data::Dumper::Dumper($got) . "\n";
#warn "expected: " . Data::Dumper::Dumper($expected) . "\n";

	if (ref $expected) {
		if (ref $expected eq 'ARRAY') {
			ok($got->is_list, "got a list value");
			is($got->length,
					scalar @$expected,
					"got a list the right length " . scalar @$expected);
			my $index = 1;
			$got->foreach(sub {
				compare_ast_tree($_[0], shift(@$expected), $str . "." . ++$index);
			});
		}
		elsif (ref $expected eq 'HASH') {
			die "hash found with > 2 elts" unless scalar keys %$expected == 1;
			isa_ok($got, 'Schip::AST::Pair', "got a pair value");
			compare_ast_tree($got->car, keys %$expected, "LH of pair matches");
			compare_ast_tree($got->cdr, values %$expected, "RH of pair matches");
		}
		elsif ($expected->isa('Schip::AST::Node')) {
			ok($expected->equals($got), "values compare ok")
				|| diag "got " . $got->deparse . " not " . $expected->deparse;
		}
		else {
			die "Non-array ref [$expected] in expected value";
		}
	}
	else {
		is($got->value, $expected, $str);
	}
}

1;
