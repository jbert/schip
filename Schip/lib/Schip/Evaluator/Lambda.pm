package Schip::Evaluator::Lambda;
use Moose;

extends qw(Schip::Evaluator::Invokable);

has 'params'	=> (is => 'ro', isa => 'Schip::AST::List');
has 'body'		=> (is => 'ro', isa => 'Schip::AST::Node');
has 'env'		=> (is => 'ro', isa => 'Schip::Env');

sub invoke {
	my $self = shift;
	my $args = shift;

	my @params = @{$self->params->value};
	my @args   = @{$args};
	die "Got " . (scalar @args) . " args but expected " . scalar (@params)
		unless scalar(@args) == scalar (@params);
	my %frame;
	while (@params) {
		my $param	= shift @params;
		my $arg		= shift @args;
		$frame{$param->value} = $arg;
	}
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
