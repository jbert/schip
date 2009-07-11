package Schip::Evaluator::Primitive;
use Moose;

has 'code'	=> (is => 'ro', isa => 'CodeRef');

extends qw(Schip::Evaluator::Invokable);

sub invoke {
	my $self = shift;
	my $args = shift;
	return $self->code->($args);
}

1;
