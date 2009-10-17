package Schip::Evaluator;
use Moose;
use Moose::Autobox;
use Schip::Env;
use Schip::Evaluator::Invokable;
use Schip::Evaluator::Primitive;
use Schip::Evaluator::Lambda;
use 5.10.0;

has 'errstr'	=> (is => 'rw', isa => 'Str');
has 'env'		=> (is => 'rw',
					isa => 'Schip::Env',
					default => sub { return __PACKAGE__->make_initial_environment(); } );

# The current level of quasiquoting. ` incremenets , and ,@ decrement.
# Package var so we can localise it
our $QUASIQUOTE_LEVEL = 0;

sub evaluate_forms {
	my ($self, @forms) = @_;

	my $value;
	eval {
		while (my $form = shift @forms) {
			$value = $self->_evaluate_form($form);
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

sub _evaluate_form {
	my $self = shift;
	my $form = shift;

	my $value;
	die_error("UNDEFINED_FORM") unless $form;
	if ($form->isa('Schip::AST::Sym')) {
		if ($QUASIQUOTE_LEVEL == 0) {
			$value = $self->env->lookup($form->value);
			die_error("UNDEFINED_SYMBOL: " . $form->value)
				unless defined $value;
		}
		else {
			$value = $form;
		}
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

	my @values			= @{$list_form->value};

	my $invoker;
	my $car	= shift @values;
	if ($QUASIQUOTE_LEVEL == 0 || ($car->isa('Schip::AST::Sym') && $car->value eq 'unquote')) {
		my $form_handler = $self->_lookup_special_form($car);
		return $form_handler->($self, \@values) if $form_handler;

		$invoker = $self->_evaluate_form($car);
		die_error("Symbol in car position is not invokable: " . $car->value)
			unless $invoker->isa('Schip::Evaluator::Invokable');
	}
	else {
		unshift @values, $car if defined $car;
	}
	my @evaluated_args = map { $self->_evaluate_form($_) } @values;

	if ($invoker) {
		my $result = $invoker->invoke(\@evaluated_args);
		return $result;
	}
	else {
		return Schip::AST::List->new(value => \@evaluated_args);
	}
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
		my $sym  = $args->[0];

		my ($sym_str, $body);
		if ($sym->isa('Schip::AST::List')) {
			# (define (foo x y) expr) form
			my $deflist = $sym;
			$sym_str	= $deflist->value->[0]->value;
			my @copy	= @{$deflist->value};
			shift @copy;
			$body 		= Schip::AST::List->new(value => [
				Schip::AST::Sym->new(value => 'lambda'),
				Schip::AST::List->new(value => \@copy),
				$args->[1],
			]);
		}
		else {
			# (define sym expr) form
			$sym_str	= $sym->value;
			$body		= $args->[1];
		}
		my $val = $eval->_evaluate_form($body);
		$eval->env->add_define($sym_str => $val);
		if ($val->isa('Schip::Evaluator::Lambda')) {
			# circular ref?
			$val->env->add_define($sym_str => $val);
		}
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
	quasiquote	=> sub {
		my $eval = shift;
		my $args = shift;

		die_error("Not exactly one arg to quasiquote") unless scalar @$args == 1;
		local $QUASIQUOTE_LEVEL = $QUASIQUOTE_LEVEL + 1;
		return $eval->_evaluate_form($args->[0]);
	},
	unquote	=> sub {
		my $eval = shift;
		my $args = shift;

		die_error("Not exactly one arg to unquote") unless scalar @$args == 1;
		die_error("Unquote found outside quasiquote") unless $QUASIQUOTE_LEVEL > 0;
		local $QUASIQUOTE_LEVEL = $QUASIQUOTE_LEVEL - 1;
		return $eval->_evaluate_form($args->[0]);
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
	$env = Schip::Evaluator::Primitive->install($env);
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

sub error {
	my $self = shift;
	my $str  = shift;
	# TODO - use Class::ErrorHandler
	$self->errstr($str);
	return;
}

1;
