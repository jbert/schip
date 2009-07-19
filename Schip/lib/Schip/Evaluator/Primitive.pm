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

sub install {
	my $class = shift;
	my $env   = shift;

	my %frame;
	foreach my $op (
		qw(error display newline),
		qw(add subtract equals multiply),
		qw(cons car cdr list),
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
			. join(", ", map { $_->value } @wrong_type);
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
		return Schip::AST::Num->new(value => $sum);
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
		return Schip::AST::Num->new(value => $sum);
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
		return Schip::AST::Num->new(value => $product);
	}
	sub symbol { '*' }


	package Schip::Evaluator::Primitive::Equals;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
		$self->die_numargs($args, 2, 1);
		$self->die_unless_type('Num', $args);
		# Controversal? have seperate bool type?

		my $first_val = $args->[0]->value;
		my @copy = @$args;
		shift @copy;
		my $same = 1;
VAL:
		foreach my $val (@copy) {
			if ($val->value != $first_val) {
				$same = 0;
				last VAL;
			}
		}
		return Schip::AST::Num->new(value => $same);
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
	}
	sub symbol { 'display' }


	package Schip::Evaluator::Primitive::Newline;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
		$self->die_numargs($args, 0);
		print "\n";
	}
	sub symbol { 'newline' }


	package Schip::Evaluator::Primitive::List;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
		return Schip::AST::List->new(value => $args);
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
		# Consing with a list in cdr gives you a list
		if ($cdr->isa('Schip::AST::List')) {
			return Schip::AST::List->new(value => [$car, @{$cdr->value}]);
		}
		else {
			return Schip::AST::Pair->new(value => [$car, $cdr]);
		}
	}
	sub symbol { 'cons' }


	package Schip::Evaluator::Primitive::Car;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
		$self->die_error("car called with != 1 args") if @$args != 1;
		$self->die_error("car called on non-pair: " . ref $args->[0])
		unless $args->[0]->isa('Schip::AST::Pair');
		my $list = $args->[0];
		# Controversial?
		die "car of empty list" if $list->value->length == 0;
		return $list->value->[0];
	}
	sub symbol { 'car' }


	package Schip::Evaluator::Primitive::Cdr;
	use Moose;
	extends qw(Schip::Evaluator::Primitive);

	sub code {
		my ($self, $args) = @_;
		$self->die_error("cdr called with != 1 args")	if @$args != 1;
		$self->die_error("car called on non-pair: " . ref $args->[0])
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
	sub symbol { 'cdr' };
}

1;
