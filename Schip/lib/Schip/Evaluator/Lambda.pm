package Schip::Evaluator::Lambda;
use Moose;

extends qw(Schip::Evaluator::Invokable);

has 'params'	=> (is => 'ro', isa => 'Schip::AST::List');
has 'body'		=> (is => 'ro', isa => 'Schip::AST::Node');
has 'env'		=> (is => 'ro', isa => 'Schip::Env');

sub invoke {
	my $self = shift;
	my $args = shift;

	my $params = $self->params;
#use Data::Dumper qw(Dumper);
#print Dumper(\@params) . "\n";
	my @args   = @{$args};
	die "Got " . (scalar @args) . " args but expected " . $params->length
		unless scalar(@args) == $params->length;
	my %frame = $params->map(sub {$_[0] => shift @args});
	my $env = $self->env;
	$env->push_frame(%frame);
	my $evaluator = Schip::Evaluator->new(env => $self->env);
	my $value = $evaluator->_evaluate_form($self->body);
	$env->pop_frame;
	return $value;
}

sub to_string {
	my $self = shift;
	return "LAMBDA: $self";
}

package Schip::Evaluator::Error;
use Moose;

has 'info'	=> (is => 'ro', isa => 'Str');

1;
