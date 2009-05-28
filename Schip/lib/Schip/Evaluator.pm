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

	has 'params'	=> (is => 'ro', isa => 'Schip::AST::List');
	has 'body'		=> (is => 'ro', isa => 'Schip::AST::Node');
	has 'env'		=> (is => 'ro', isa => 'Schip::Env');

	sub invoke {
		my $self = shift;
		my $args = shift;

		my $env = $self->env;
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
		$env->push_frame(%frame);
		my $evaluator = Schip::Evaluator->new(env => $self->env);
		my $value = $evaluator->_evaluate_form($self->body);
		$env->pop_frame;
		return $value;
	}

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
		$value = $self->_evaluate_form($form);
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

sub _evaluate_form {
	my $self = shift;
	my $form = shift;

	my $value;
	die_error("UNDEFINED_FORM") unless $form;
	if ($form->isa('Schip::AST::Sym')) {
		$value = $self->env->lookup($form->value);
		die_error("UNDEFINED_SYMBOL: " . $form->value)
			unless defined $value;
	}
	elsif ($form->isa('Schip::AST::Atom')) {
		$value = $form;
	}
	elsif ($form->isa('Schip::AST::List')) {
		$value = $self->_evaluate_list($form);
	}
	else {
		die_error("unrecognised form type: " . ref $form) unless $form;
	}
	return $value;
}

sub _evaluate_list {
	my $self		= shift;
	my $list_form	= shift;

	my $values	= $list_form->value;
	my $car		= shift @$values;

	my $form_handler = $self->_lookup_special_form($car);
	return $form_handler->($self, $values) if $form_handler;

	my $carVal	= $self->_evaluate_form($car);
	die_error("Symbol in car position is not invokable: " . $car->value)
		unless $carVal->isa('Schip::Evaluator::Invokable');

	my @evaluated_args = map { $self->_evaluate_form($_) } @$values;
	return $carVal->invoke(\@evaluated_args);
}

my %special_forms = (
	begin 		=> sub {
		my $eval = shift;
		my $args = shift;

		my @vals = map { $eval->_evaluate_form($_) } @$args;
		return $vals[-1];
	},
	define		=> sub {
		my $eval = shift;
		my $args = shift;

		my $sym		= shift @$args;
		my $sym_str = $sym->value;
		my $body	= shift @$args;
		my $val 	= $eval->_evaluate_form($body);
		$eval->env->push_frame($sym_str => $val);
		return $val;
	},
	lambda		=> sub {
		my $eval = shift;
		my $args = shift;

		my $params	= shift @$args;
		my $body	= shift @$args;

		return Schip::Evaluator::Lambda->new(
			params	=> $params,
			body	=> $body,
			env		=> $eval->env->clone,
		);
	},
);

sub _lookup_special_form {
	my $self = shift;
	my $form = shift;
	return unless $form->isa('Schip::AST::Sym');
	return $special_forms{$form->value};
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

	# TODO: write in terms of fold, and make generic

	my $die_unless_numeric = sub {
		my $args = shift;
		my @non_numeric = grep { !$_->isa('Schip::AST::Num') } @$args;
		die_error("Non-numeric argument to +: "
				. join(", ", map { $_->value } @non_numeric))
			if @non_numeric;
	};

	my $plus = Schip::Evaluator::Primitive->new(
		code => sub {
			my $args = shift;
			$die_unless_numeric->($args);
			my $sum = sum map { $_->value } @$args;
			return Schip::AST::Num->new(value => $sum);
		}
	);
	$env->push_frame('+' => $plus);

	# TODO - pull to seperate module
#	use Math::BigRat;
#	my $divide = Schip::Evaluator::Primitive->new(
#		code => sub {
#			my $args = shift;
#			$die_unless_numeric->($args);
#			my @arg_nums = map { $_->value } @$args;
#			my $result = Math::BigRat->new(shift @arg_nums);
#			while (@arg_nums) {
#				my $arg = shift @arg_nums;
#				die_error("Division by zero") unless $arg;
#				$result /= $arg;
#			}
#			return Schip::AST::Num->new(value => $result->bstr);
#		}
#	);
#	$env->push_frame('/' => $divide);

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
