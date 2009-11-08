package Schip::Evaluator::Primitive;
use Moose;
use Moose::Autobox;

has 'code'	=> (is => 'ro', isa => 'CodeRef');

extends qw(Schip::Evaluator::Invokable);

sub invoke {
	my $self = shift;
	my $args = shift;
	return $self->code($args);
}

sub sym_ok {
	my $self = shift;
	return Schip::AST::Sym->new("'ok");
}

sub install {
	my $class = shift;
	my $env   = shift;

	my %frame;
	foreach my $op (
		qw(error display newline),
		qw(add subtract numequals multiply),
		qw(cons car cdr list),
		qw(not),
        qw(equals isnull),
		) {
		my $subclass = "Schip::Evaluator::Primitive::" . ucfirst $op;
		my $instance = $subclass->new;
		$frame{$instance->symbol} = $instance;
	}
	$env->push_frame(%frame);
	return $env;
}

sub die_numargs {
	my ($self, $args, $num_args, $atleast) = @_;
	if ($atleast) {
		$self->die_error(ucfirst($self->symbol) . " called with < " . $num_args . " arg")
			if @$args < $num_args;
	}
	else {
		$self->die_error(ucfirst($self->symbol) . " called with != " . $num_args . " arg")
			if @$args != $num_args;
	}
	return;
}

sub die_unless_type {
	my ($self, $type, $args) = @_;

	my $class = "Schip::AST::$type";
	my @wrong_type = grep { !$_->isa($class) } @$args;
	if (@wrong_type) {
		my $err = "Non-" . $class->description . " argument(s) to " . $self->symbol . ":"
			. join(", ", @wrong_type);
		$self->die_error($err);
	}
}

sub die_error {
	my ($self, $error_str) = @_;
	die Schip::Evaluator::Error->new(info => $error_str);
}

{
	package Schip::Evaluator::Primitive::Add;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);
	use List::Util qw(sum);

	sub code {
		my ($self, $args) = @_;
		$self->die_unless_type('Num', $args);
		my $sum = sum map { $_->value } @$args;
		return Schip::AST::Num->new($sum);
	}
	sub symbol { '+' }


	package Schip::Evaluator::Primitive::Subtract;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
		$self->die_unless_type('Num', $args);
		my $sum = $args->[0]->value;
		shift @$args;
		$sum -= $_->value for @$args;
		return Schip::AST::Num->new($sum);
	}
	sub symbol { '-' }


	package Schip::Evaluator::Primitive::Multiply;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
		$self->die_unless_type('Num', $args);
		my $product = 1;
		$product *= $_->value for @$args;
		return Schip::AST::Num->new($product);
	}
	sub symbol { '*' }


	package Schip::Evaluator::Primitive::Numequals;
	use Moose;
	extends qw(Schip::Evaluator::Primitive::Equals);

	sub code {
		my ($self, $args) = @_;
		$self->die_unless_type('Num', $args);
        return $self->SUPER::code($args);
    }
	sub symbol { '=' }

	package Schip::Evaluator::Primitive::Error;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
		$self->die_numargs($args, 1);
		$self->die_unless_type('Str', $args);
		my ($str) = map { $_->value } @$args;
		$str //= "Unspecified error";
		$self->die_error($str);
	}
	sub symbol { 'error' }


	package Schip::Evaluator::Primitive::Display;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
		$self->die_numargs($args, 1);
		print $args->[0]->to_string;
		return $self->sym_ok;
	}
	sub symbol { 'display' }


	package Schip::Evaluator::Primitive::Newline;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
		$self->die_numargs($args, 0);
		print "\n";
		return $self->sym_ok;
	}
	sub symbol { 'newline' }


	package Schip::Evaluator::Primitive::List;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
		return Schip::AST::Pair->make_list(@$args);
	}
	sub symbol { 'list' }


	package Schip::Evaluator::Primitive::Cons;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
		$self->die_error("cons called with != 2 args") if @$args != 2;
		my $car = $args->[0];
		my $cdr = $args->[1];
		return Schip::AST::Pair->new($car, $cdr);
	}
	sub symbol { 'cons' }


	package Schip::Evaluator::Primitive::Car;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
		$self->die_error("car called with != 1 args") if @$args != 1;
		my $arg = $args->[0];
		$self->die_error("car called on non-pair: " . ref $arg)
			unless $arg->is_pair;
		return $arg->car;
	}
	sub symbol { 'car' }


	package Schip::Evaluator::Primitive::Cdr;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
		$self->die_error("cdr called with != 1 args") if @$args != 1;
		my $arg = $args->[0];
		$self->die_error("cdr called on non-pair: " . ref $arg)
			unless $arg->is_pair;
		return $arg->cdr;
	}
	sub symbol { 'cdr' };


	package Schip::Evaluator::Primitive::Not;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
		$self->die_unless_type('Num', $args);
		return Schip::AST::Num->new($args->[0] ? 0 : 1);
	}
	sub symbol { 'not' }

	package Schip::Evaluator::Primitive::Equals;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
        $self->die_numargs($args, 2, 1);
        my @copy = @$args;
        my $first = shift @copy;
        my $same = 1;
    VAL:
        foreach my $val (@copy) {
            unless ($val->equals($first)) {
                $same = 0;
                last VAL;
            }
        }
        return Schip::AST::Num->new($same);
    }
	sub symbol { 'equal?' }


	package Schip::Evaluator::Primitive::Isnull;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
        $self->die_numargs($args, 1);
        my $is_null = $args->[0]->isa('Schip::AST::NilPair')
                    || ($args->[0]->is_list && $args->[0]->length == 0);
        return Schip::AST::Num->new($is_null ? 1 : 0);
    }
	sub symbol { 'null?' }
}

1;
