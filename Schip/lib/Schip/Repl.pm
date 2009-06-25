package Schip::Repl;
use Moose;
use Schip::Parser;
use Schip::Evaluator;
use 5.10.0;

has '_parser'	=> (is => 'rw', isa => 'Schip::Parser', default => sub { Schip::Parser->new }, );
has '_evaluator'	=> (is => 'rw', isa => 'Schip::Evaluator', default => sub { Schip::Evaluator->new }, );
has 'in'		=> (is => 'rw', default => sub { \*STDIN },);
has 'out'		=> (is => 'rw', default => sub { \*STDOUT }, );
has 'interactive'	=> (is => 'rw', default => 1,);

sub run {
	my $self = shift;

	my $command_count = 1;
	my $infh = $self->in;
	my $outfh = $self->out;
	$| = 1;
	$self->_banner if $self->interactive;
REPL:
	while(1) {
		my $prompt = "schip $command_count> ";
		print $outfh $prompt if $self->interactive;
		my $line = <$infh>;
		last REPL unless defined $line;
		chomp $line;
		next REPL if $line eq '';
		last REPL if $line eq 'quit';

		$command_count++;
		my $tree = $self->_parser->parse($line);
		my $response;
		if ($tree) {
			my $result = $self->_evaluator->evaluate_form($tree);
			if ($result) {
				$response = $result->to_string;
			}
			else {
				$response = "Evaluation error: " . $self->_evaluator->errstr;
			}
		}
		else {
			$response = "Parse error: " . $self->_parser->errstr;
		}
		print $outfh $response . "\n";
	};

	return 1;
}

sub _banner {
	my $self = shift;

	my $outfh = $self->out;
	print $outfh "SCHIP - Scheme in perl\n\n";
	return 1;
}

1;
