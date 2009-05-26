package Schip::Evaluator;
use Moose;
use Moose::Autobox;
use List::MoreUtils qw(all);
use List::Util qw(sum);
use Schip::Env;

{
	package Schip::Evaluator::Invokable;
	use Moose;

	package Schip::Evaluator::Primitive;
	use Moose;

	has 'code'	=> (is => 'ro', isa => 'CodeRef');

	extends qw(Schip::Evaluator::Invokable);

	sub invoke {
		my $self = shift;
		my $args = shift;
		return $self->code->($args);
	}

	package Schip::Evaluator::Lambda;
	use Moose;

	extends qw(Schip::Evaluator::Invokable);


	package Schip::Evaluator::Error;
	use Moose;

	has 'info'	=> (is => 'ro', isa => 'Str');
}

has 'errstr'	=> (is => 'rw', isa => 'Str');
has 'env'		=> (is => 'rw',
					isa => 'Schip::Env',
					default => sub { return __PACKAGE__->make_initial_environment(); } );

sub evaluate_form {
	my $self = shift;
	my $form = shift;

	my $value;
	eval {
		die_error("UNDEFINED_FORM") unless $form;
		if ($form->isa('Schip::AST::Atom')) {
			$value = $form;
		}
		elsif ($form->isa('Schip::AST::List')) {
			$value = $self->_evaluate_list($form);
		}
		else {
			die_error("unrecognised form type: " . ref $form) unless $form;
		}
	};
	if ($@) {
		if (UNIVERSAL::isa($@, 'Schip::Evaluator::Error')) {
			return $self->error($@->info);
		}
		else {
			die $@;
		}
	}
	return $value;
}

sub _evaluate_list {
	my $self		= shift;
	my $list_form	= shift;

	my $values	= $list_form->value;
	my $car		= shift @$values;
	die_error("Non-symbol in car position: " . ref $car)
		unless $car->isa('Schip::AST::Sym');
	# TODO: handle special forms
	my $carVal	= $self->env->lookup($car->value);
	die_error("Symbol in car position is not invokable: " . $car->value)
		unless $carVal->isa('Schip::Evaluator::Invokable');

	my @evaluated_args = map { $self->evaluate_form($_) } @$values;
	return $carVal->invoke(\@evaluated_args);
}

sub make_initial_environment {
	my $class = shift;
	my $env = Schip::Env->new;
	$env = $class->_install_primitives($env);
	return $env;
}

sub _install_primitives {
	my $class = shift;
	my $env   = shift;

	my $plus = Schip::Evaluator::Primitive->new(
		code => sub {
			my $args = shift;
			my @non_numeric = grep { !$_->isa('Schip::AST::Num') } @$args;
			die_error("Non-numeric argument to +: "
				. join(", ", map { $_->value } @non_numeric))
				if @non_numeric;
			my $sum = sum map { $_->value } @$args;
			return Schip::AST::Num->new(value => $sum);
		}
	);
	$env->push_frame('+' => $plus);
	return $env;
}

sub die_error {
	my $error = shift;
	die Schip::Evaluator::Error->new(info => $error);
}

sub errstr {
	my $self = shift;
	return $self->errstr;
}

sub error {
	my $self = shift;
	my $str  = shift;
	# TODO - use Class::ErrorHandler
	$self->errstr($str);
	return;
}

1;
