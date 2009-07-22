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
	my $result = $carVal->invoke(\@evaluated_args);
	return $result;
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
