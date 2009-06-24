package Schip::Repl;
use Moose;
use Schip::Parser;
use Schip::Evaluator;
use 5.10.0;

has 'parser'	=> (is => 'rw', isa => 'Schip::Parser', default => sub { Schip::Parser->new }, );
has 'evaluator'	=> (is => 'rw', isa => 'Schip::Evaluator', default => sub { Schip::Evaluator->new }, );
has 'in'		=> (is => 'rw', default => sub { \*STDIN },);
has 'out'		=> (is => 'rw', default => sub { \*STDOUT }, );

sub run {
	my $self = shift;

	my $prompt = "schip> ";
	my $infh = $self->in;
	my $outfh = $self->out;
	$| = 1;
REPL:
	while(1) {
		print $outfh $prompt;
		my $line = <$infh>;
		last REPL unless defined $line;
		last REPL if $line eq 'quit';
		my $tree = $self->parser->parse($line);
		my $response;
		if ($tree) {
			my $result = $self->evaluator->evaluate_form($tree);
			if ($result) {
				$response = $result->to_string;
			}
			else {
				$response = "Evaluation error: " . $self->evaluator->errstr;
			}
		}
		else {
			$response = "Parse error: $self->parser->errstr";
		}
		print $outfh $response . "\n";
	};
}

1;
