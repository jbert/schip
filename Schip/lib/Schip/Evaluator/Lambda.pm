package Schip::Evaluator::Lambda;
use Moose;

extends qw(Schip::Evaluator::Invokable);

has 'params'	=> (is => 'ro', isa => 'Schip::AST::List');
has 'rest'	    => (is => 'ro', isa => 'Maybe[Schip::AST::Sym]');
has 'body'		=> (is => 'ro', isa => 'Schip::AST::Node');
has 'env'		=> (is => 'ro', isa => 'Schip::Env');

sub invoke {
	my $self = shift;
	my $args = shift;

	my $params = $self->params;
	my $rest   = $self->rest;

#use Data::Dumper qw(Dumper);
#print "params: " . $params->to_string . "\n";
#print "rest: " . $rest->to_string . "\n";
	my @args   = @{$args};

    my $num_args = scalar @args;
	die Schip::Evaluator::Error->new(info => "Got $num_args args but expected " . $params->length)
		unless (defined $rest && $num_args >= $params->length)
            || (!defined $rest && $num_args == $params->length);
	my %frame = $params->map(sub {$_[0] => shift @args});
    $frame{$rest} = Schip::AST::List->new(@args) if defined $rest;
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
