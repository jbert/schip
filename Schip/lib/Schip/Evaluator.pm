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
	my $self = shift;

    my $value;
	eval {
        $value = $self->_evaluate_forms(@_);
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

sub _evaluate_forms {
	my ($self, @forms) = @_;

    # Implicit begin
	my $value;
    while (defined (my $form = shift @forms)) {
        $value = $self->_evaluate_form($form);
    }
	return $value;
}

sub _evaluate_form {
	my $self = shift;
	my $form = shift;

	my $value;
	die_error("UNDEFINED_FORM") unless defined $form;
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
	elsif ($form->is_list) {
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

    if ($list_form->length == 0) {
        if ($QUASIQUOTE_LEVEL) {
            return $list_form;
        }
        else {
            die_error("Eval of empty list")
        }
    }

	my $car	= $list_form->car;
	if ($QUASIQUOTE_LEVEL > 0
        && !($car->isa('Schip::AST::Sym') && $car->value eq 'unquote')) {
		my @evaluated_args = $list_form->map(sub { my $form = shift; $self->_evaluate_form($form);});
		return Schip::AST::Pair->make_list(@evaluated_args);
	}

	my $form_handler = $self->_lookup_special_form($car);
	return $form_handler->($self, $list_form) if $form_handler;

	# Not a special form
	my $invoker = $self->_evaluate_form($car);
	die_error("Symbol in car position is not invokable: " . $car->to_string)
		unless $invoker->isa('Schip::Evaluator::Invokable');

	my @evaluated_args = $list_form->map(sub { $self->_evaluate_form($_[0]); }, 1);
	my $result = $invoker->invoke(\@evaluated_args);
	return $result;
}

my %special_forms = (
	begin 		=> sub {
		my $eval = shift;
		my $form = shift;

		my @vals = $form->map(sub { $eval->_evaluate_form($_[0]); }, 1);
		return $vals[-1];
	},
	define		=> sub {
		my $eval = shift;
		my $form = shift;
		my $cadr  = $form->cadr;

		my ($sym, $body);
		if ($cadr->is_pair) {
			# (define (foo x y) expr1) or
			# (define (foo x y) expr1 expr2) form
			my $deflist 	= $cadr;
			$sym			= $deflist->car;
			my $lambda_args	= $deflist->cdr;
            $body = Schip::AST::Pair->new(
                Schip::AST::Sym->new('lambda'),
                Schip::AST::Pair->new(
                    $lambda_args,
                    $form->cddr));
		}
		else {
			# (define sym expr) form
			$sym		= $cadr;
			$body		= $form->caddr;
		}
        die_error("Internal error $sym is not a sym")
            unless $sym->isa('Schip::AST::Sym');
		my $val = $eval->_evaluate_form($body);
		$eval->env->add_define($sym => $val);
		if ($val->isa('Schip::Evaluator::Lambda')) {
			# circular ref?
			$val->env->add_define($sym => $val);
		}
		return $val;
	},
	lambda		=> sub {
		my $eval = shift;
		my $form = shift;

		my $raw_params = $form->cadr;
        my ($params, $rest);
        if ($raw_params->is_list) {
            my @vals;
            $raw_params->foreach(sub { push @vals, shift; });
            $params = Schip::AST::Pair->make_list(@vals);
        }
        else {
            my @params;
            my $node = $raw_params;
        NODE:
            while ($node) {
                push @params, $node->car;
                $node = $node->cdr;
                if (!$node->is_pair) {
                    $rest = $node;
                    last NODE;
                }
            }
            $params = Schip::AST::Pair->make_list(@params);
        }

		return Schip::Evaluator::Lambda->new(
			params	=> $params,
            rest    => $rest,
			body	=> $form->cddr,
			env		=> $eval->env->clone,
		);
	},
	quote		=> sub {
		my $eval = shift;
		my $form = shift;

		die_error("Not exactly one arg to quote") unless $form->length == 2;
		return $form->cadr;
	},
	quasiquote	=> sub {
		my $eval = shift;
		my $form = shift;

		die_error("Not exactly one arg to quasiquote") unless $form->length == 2;
		local $QUASIQUOTE_LEVEL = $QUASIQUOTE_LEVEL + 1;
		return $eval->_evaluate_form($form->cadr);
	},
	unquote	=> sub {
		my $eval = shift;
		my $form = shift;

		die_error("Not exactly one arg to unquote") unless $form->length == 2;
		die_error("Unquote found outside quasiquote") unless $QUASIQUOTE_LEVEL > 0;
		local $QUASIQUOTE_LEVEL = $QUASIQUOTE_LEVEL - 1;
		return $eval->_evaluate_form($form->cadr);
	},
	if			=> sub {
		my $eval = shift;
        my $form = shift;

		my $condition	= $form->cadr;
		my $trueform	= $form->caddr;
		my $falseform	= $form->cadddr;
		die_error("No true branch")		unless defined $trueform;
		die_error("No false branch")	unless defined $falseform;
		my $result 		= $eval->_evaluate_form($condition);
		return unless defined $result;
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
		when ($_->is_pair)                  { return $_->is_null ? 0 : 1; }
		when ($_->isa('Schip::AST::Num')) 	{ return $_->value != 0; }
		when ($_->isa('Schip::AST::Str')) 	{ return $_->value ne ""; }
		when ($_->isa('Schip::AST::Sym'))	{ return 1; }
		default								{
            die_error("Unhandled truth case: " . (ref $node ? ref $node : $node));
        }
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
