{
	package Schip::AST::Node;
	use Moose;

	has 'type'	=> (is => 'rw', isa => 'Str');

	sub description { die "Abstract node doesn't have a description"; }

	sub equals		{ die "Abstract node can't compare for equality"; }

	# Most forms string representation is the same as their deparse
	sub deparse	{
		my $self = shift;
		return $self->to_string(1);
	}

	sub is_null { return 0; }
}

{
	package Schip::AST::Atom;
	use Moose;

	extends qw(Schip::AST::Node);

	sub description { 'atomic'; }

	sub equals { 
		my $self = shift;
		my $rhs  = shift;
		return ref $self eq ref $rhs && $self->value eq $rhs->value;
	}
}

{
	package Schip::AST::Num;
#	use Math::BigRat;
	use Moose;

	extends qw(Schip::AST::Atom);
#	has 'value'	=> (is => 'rw', isa => 'Num|Math::BigRat');
	has 'value'	=> (is => 'rw', isa => 'Num');

	sub to_string {
		my ($self, $deparse) = @_;
		return $self->value;
	}

	sub description { 'numeric'; }
}

{
	package Schip::AST::Sym;
	use Moose;

	extends qw(Schip::AST::Atom);
	has 'value'	=> (is => 'rw', isa => 'Str');

	sub to_string {
		my ($self, $deparse) = @_;
		return $self->value;
	}

	sub description { 'symbolic'; }
}

{
	package Schip::AST::Str;
	use Moose;

	extends qw(Schip::AST::Atom);
	has 'value'	=> (is => 'rw', isa => 'Str');

	sub to_string {
		my ($self, $deparse) = @_;
		if ($deparse) {
			return '"' . $self->_escape_quotes . '"';
		}
		else {
			return $self->value;
		}
	}

	sub _escape_quotes {
		my $self = shift;
		my $str  = shift || $self->value;
		$str =~ s/\\/\\\\/g;
		$str =~ s/"/\\"/g;
		return $str;
	}

	sub description { 'string'; }
}

{
	package Schip::AST::Pair;
	use Moose;
	use Moose::Autobox;

	extends qw(Schip::AST::Node);
	has 'value'	=> (is			=> 'rw',
					isa			=> 'ArrayRef[Schip::AST::Node]',
					default		=> sub {[]}, );

=pod

...we want to check at Pair->new time whether cdr isa list and if so, make a list instead
	...that runs head into the "can we share structure between one list and another, which we can't
	...so we could copy
...if we do this then we need to make sure 'cons' comes via here (which is must anyway, really)


....!OK! strategy:
	- we move to using ::Pair everywhere
		- hard work, since we expose $list->value in various places
	- possible optimisation:
		- except when we know we're creating a list. e.g. '(1 2 3), (list a b c) etc.
		- taking 'cdr' on a list "breaks" it, so we then:
			- create the equivalent cons list (whose values are the same values as where in the list,
				so any refs to those values are still good) as a list of ::Pairs
			- make the ::List just proxy to the cons pairs
				- which works if we avoid the ->value encapsulation breaking
			- provide rich interface to s.ast.list for functions which only touch values (caNdr)
				(nth, map, etc) to allow fast access to list without 'breaking' it

=cut

	sub to_string {
		my ($self, $deparse, $parent_hid_dot) = @_;
		my ($car, $cdr) = ($self->car, $self->cdr);
		my $ret = '';
		my $hide_dot = $self->cdr->isa('Schip::AST::Pair');
		$ret .= '(' unless $parent_hid_dot;
		$ret .= $car->to_string($deparse, $hide_dot) . ' ';
		$ret .= '. ' unless $hide_dot;
		$ret .= $cdr->to_string($deparse, $hide_dot);
		$ret .= ')' unless $parent_hid_dot;
		return $ret;
	}

	sub car {
		my $self = shift;
		return $self->value->[0];
	}

	sub cdr {
		my $self = shift;
		return $self->value->[1];
	}

	sub description { 'pair'; }

	sub equals {
		my $self = shift;
		my $rhs  = shift;
		return ref $self eq ref $rhs
			&& $self->value->[0]->equals($rhs->value->[0])
			&& $self->value->[1]->equals($rhs->value->[1]);
	}
}

{
	package Schip::AST::List;
	use Moose;
	use Moose::Autobox;

	# A list is just a pair whose cdr is also a list
	extends qw(Schip::AST::Pair);

	sub to_string {
		my ($self, $deparse) = @_;
		return "(" . $self->value->map(sub {$_->to_string($deparse)})->join(" ") . ")";
	}

	sub description { 'list'; }

	sub equals {
		my $self = shift;
		my $rhs  = shift;

		return 0 unless ref $self eq ref $rhs;
		return 0 unless $self->value->length == $rhs->value->length;
		for my $i (0..($self->value->length - 1)) {
			return 0 unless $self->value->[$i] == $rhs->value->[$i];
		}
		return 1;
	}

	sub is_null {
		my $self = shift;
		return $self->value->length == 0;
	}
}

1;
