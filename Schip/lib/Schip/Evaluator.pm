package Schip::Evaluator;
use Moose;
use Moose::Autobox;
use List::MoreUtils qw(all);
use List::Util qw(sum);
use Schip::Env;
use Schip::Evaluator::Invokable;
use Schip::Evaluator::Primitive;
use Schip::Evaluator::Lambda;
use 5.10.0;


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

	my @values	= @{$list_form->value};
	my $car		= shift @values;

	my $form_handler = $self->_lookup_special_form($car);
	return $form_handler->($self, \@values) if $form_handler;

	my $carVal	= $self->_evaluate_form($car);
	die_error("Symbol in car position is not invokable: " . $car->value)
		unless $carVal->isa('Schip::Evaluator::Invokable');

	my @evaluated_args = map { $self->_evaluate_form($_) } @values;
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

		my $sym		= $args->[0];
		my $sym_str = $sym->value;
		my $body	= $args->[1];
		my $val 	= $eval->_evaluate_form($body);
		$eval->env->push_frame($sym_str => $val);
		return $val;
	},
	lambda		=> sub {
		my $eval = shift;
		my $args = shift;

		my $params	= $args->[0];
		my $body	= $args->[1];

		return Schip::Evaluator::Lambda->new(
			params	=> $params,
			body	=> $body,
			env		=> $eval->env->clone,
		);
	},
	quote		=> sub {
		my $eval = shift;
		my $args = shift;

		die_error("Not exactly one arg to quote") unless scalar @$args == 1;
		return $args->[0];
	},
	if			=> sub {
		my $eval = shift;
		my $args = shift;

		my $condition	= $args->[0];
		my $trueform	= $args->[1];
		my $falseform	= $args->[2];
		die_error("No true branch")		unless $trueform;
		die_error("No false branch")	unless $falseform;
		my $result 		= $eval->_evaluate_form($condition);
		return unless $result;
		if (__PACKAGE__->_value_is_true($result)) {
			return $eval->_evaluate_form($trueform);
		}
		else {
			return $eval->_evaluate_form($falseform);
		}
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
	# TODO: this wants to be a class, with helpers

	my $die_unless_type = sub {
		my $type		= shift;
		my $prim		= shift;
		my $args		= shift;

		my $class = "Schip::AST::$type";
		my @wrong_type = grep { !$_->isa($class) } @$args;
		if (@wrong_type) {
			my $err = "Non-" . $class->description . " argument(s) to $prim: "
				. join(", ", map { $_->value } @wrong_type);
			die_error($err);
		};
	};

	my $plus = Schip::Evaluator::Primitive->new(
		code => sub {
			my $args = shift;
			$die_unless_type->('Num', '+', $args);
			my $sum = sum map { $_->value } @$args;
			return Schip::AST::Num->new(value => $sum);
		}
	);
	$env->push_frame('+' => $plus);

	my $error = Schip::Evaluator::Primitive->new(
		code => sub {
			my $args = shift;
			die_error("Error called with > 1 arg") if @$args > 1;
			$die_unless_type->('Str', 'error', $args);
			my ($str) = map { $_->value } @$args;
			$str //= "Unspecified error";
			die_error($str);
		}
	);
	$env->push_frame('error' => $error);

	my $list = Schip::Evaluator::Primitive->new(
		code => sub {
			my $args = shift;
			return Schip::AST::List->new(value => $args);
		}
	);
	$env->push_frame('list' => $list);

	my $cons = Schip::Evaluator::Primitive->new(
		code => sub {
			my $args = shift;
			die_error("cons called with != 2 args") if @$args != 2;
			my $car = $args->[0];
			my $cdr = $args->[1];
			# Consing with a list in cdr gives you a list
			if ($cdr->isa('Schip::AST::List')) {
				return Schip::AST::List->new(value => [$car, @{$cdr->value}]);
			}
			else {
				return Schip::AST::Pair->new(value => [$car, $cdr]);
			}
		}
	);
	$env->push_frame('cons' => $cons);

	my $car = Schip::Evaluator::Primitive->new(
		code => sub {
			my $args = shift;
			die_error("car called with != 1 args")	if @$args != 1;
			die_error("car called on non-pair: " . ref $args->[0])
				unless $args->[0]->isa('Schip::AST::Pair');
			my $list = $args->[0];
			# Controversial?
			die "car of empty list" if $list->value->length == 0;
			return $list->value->[0];
		}
	);
	$env->push_frame('car' => $car);

	my $cdr = Schip::Evaluator::Primitive->new(
		code => sub {
			my $args = shift;
			die_error("cdr called with != 1 args")	if @$args != 1;
			die_error("car called on non-pair: " . ref $args->[0])
				unless $args->[0]->isa('Schip::AST::Pair');
			my $list = $args->[0];
			die "cdr of empty list" if $list->value->length == 0;
			if ($list->value->length == 1) {
				# Should we have a global, static object for the null list?
				return Schip::AST::List->new(value => []);
			}
			else {
				# Symettric to conditional in cons.
				if ($list->isa('Schip::AST::List')) {
					my @newlist = @{$list->value};
					shift @newlist;
					return Schip::AST::List->new(value => \@newlist);
				}
				elsif ($list->isa('Schip::AST::Pair')) {
					return $list->value->[1];
				}
				else {
					die_error("Unknown type in cdr: " . ref($list->value));
				}
			}
			return $list->value->[0];
		}
	);
	$env->push_frame('cdr' => $cdr);

	# TODO - pull to seperate module
#	use Math::BigRat;
#	my $divide = Schip::Evaluator::Primitive->new(
#		code => sub {
#			my $args = shift;
#			$die_unless_type->('Num', '+', $args);
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

# Hack, hack, hacketty hack.
# TODO: Should this be a method on s.ast.node? (fits nicely, but that embeds evaluator semantics
# into the syntax node.
# Should we have an s.ast.bool type and a way of coercing other types to that?
sub _value_is_true {
	my $class = shift;
	my $node  = shift;
	given ($node) {
		when ($_->isa('Schip::AST::List'))	{ return $_->value->length > 0; }
		when ($_->isa('Schip::AST::Num')) 	{ return $_->value != 0; }
		when ($_->isa('Schip::AST::Str')) 	{ return $_->value ne ""; }
		when ($_->isa('Schip::AST::Sym'))	{ return 1; }
		default								{ die_error("Unhandled truth case"); }
	}
}

sub die_error {
	my $error_str = shift;
	die Schip::Evaluator::Error->new(info => $error_str);
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
