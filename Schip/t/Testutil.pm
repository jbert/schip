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
				else {
					die "Non-array ref in expected value";
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
