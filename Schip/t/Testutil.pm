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
			$expectedDeparse = $expected->{deparse} if $expected->{deparse};
			$expected		 = $expected->{value};
		}

		note("Checking $code");

		my $tree		= $parser->parse($code);
		my $deparse		= $tree->to_string;
		is($deparse, $expectedDeparse, "parsed code deparses to same string");
		my $evaluator	= Schip::Evaluator->new;
		my $result		= $evaluator->evaluate_form($tree);
		if (defined $expected) {
			ok($result, "form evaluated ok");
			note("failed with errstr: " . $evaluator->errstr) if !$result;
			if (ref $expected) {
				if (ref $expected eq 'ARRAY') {
					# TODO - support nesting
					isa_ok($result, 'Schip::AST::List', "got a list value");
					is($result->value->length,
						scalar @$expected,
						"got a list the right length " . scalar @$expected);
					while(@$expected) {
						my $expected_val = shift @$expected;
						my $got = $result->value->shift;
						is($got->value, $expected_val, "index is correct");
					}
				}
				elsif ($expected->isa('Schip::AST::Node')) {
					ok($expected->equals($result), "values compare ok")
						|| diag "got " . $result->to_string . " not " . $expected->to_string;
				}
				else {
					die "Non-array ref [$expected] in expected value";
				}
			}
			else {
				is($result->value, $expected, "form [$code] evaluates to expected val");
			}
		}
		else {
			# TODO: check errstr, line # etc
			ok(!defined $result, "form returned undef");
		}
	}
}

1;
