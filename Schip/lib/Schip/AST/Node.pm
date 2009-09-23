use strict;
use warnings;
{
	package Schip::AST::Node;
	use base qw(Class::Accessor::Fast);
	__PACKAGE__->mk_accessors qw(type);

	sub description { die "Abstract node doesn't have a description"; }

	sub equals		{ die "Abstract node can't compare for equality"; }

	# Most forms string representation is the same as their deparse
	sub deparse	{
		my $self = shift;
		return $self->to_string(1);
	}
}

{
	package Schip::AST::Atom;
	use base qw(Schip::AST::Node);
	__PACKAGE__->mk_accessors qw(value);

	use overload
		'""' => "to_string";

	sub new {
		my ($class, $value) = @_;
		return bless \$value, $class;
	}

	sub description { 'atomic'; }

	sub value {
		my $self = shift;
		return $$self;
	}

	sub to_string {
		my ($self, $deparse) = @_;
		return $self->value;
	}

	sub equals { 
		my $self = shift;
		my $rhs  = shift;
		return ref $self eq ref $rhs && $self eq $rhs;
	}
}

{
	package Schip::AST::Num;
	use base qw(Schip::AST::Atom);

	sub description { 'numeric'; }
}

{
	package Schip::AST::Sym;
	use base qw(Schip::AST::Atom);

	sub description { 'symbolic'; }
}

{
	package Schip::AST::Str;
	use base qw(Schip::AST::Atom);

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
	use base qw(Schip::AST::Node);
	__PACKAGE__->mk_accessors qw(car cdr);

	sub new {
		my ($class, $car, $cdr) = @_;
		return $class->SUPER::new({car => $car, cdr => $cdr});
	}

=pod


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

	sub description { 'pair'; }

	sub equals {
		my $self = shift;
		my $rhs  = shift;
		return ref $self eq ref $rhs
			&& $self->car->equals($rhs->car)
			&& $self->cdr->equals($rhs->cdr);
	}
}

{
	package Schip::AST::NilPair;
	use base qw(Schip::AST::Node);

	my $singleton = bless [], __PACKAGE__;
	sub new { return $singleton; }

	sub to_string { return "()"; }

	sub description { 'pair'; }

	sub equals {
		my $self = shift;
		my $rhs  = shift;
		return ref $self eq ref $rhs;
	}
}

{
	package Schip::AST::List;
	use base qw(Schip::AST::Node);
	__PACKAGE__->mk_accessors qw(elts);

	sub new {
		my ($class, @elts) = @_;
		return $class->SUPER::new({elts => \@elts});
	}

	sub to_string {
		my ($self, $deparse) = @_;
		return "(" . join(" ", map { $_->to_string($deparse); } @{$self->elts}) . ")";
	}

	sub description { 'list'; }

	sub equals {
		my $self = shift;
		my $rhs  = shift;

		return 0 unless ref $self eq ref $rhs;
		return 0 unless $self->elts->length == $rhs->elts->length;
		for my $i (0..($self->elts->length - 1)) {
			return 0 unless $self->elts->[$i] == $rhs->elts->[$i];
		}
		return 1;
	}

	sub car {
		my $self = shift;
		return $self->elts->[0];
	}

	# TODO - this does need to construct the cons'd list, but it should
	# stash it internally so that future refs to this list (or future calls to cdr)
	# refer to the same items.
	sub cdr {
		my $self = shift;
		my $cons_list = $self->_as_cons_list;
		return $cons_list->cdr;
	}

	sub _as_cons_list {
		my $self = shift;
		my $cons_list = Schip::AST::NilPair->new;
		foreach my $elt (reverse @{$self->elts}) {
			$cons_list = Schip::AST::Pair->new($elt, $cons_list);
		}
		return $cons_list;
	}

	sub push {
		my ($self, @elts) = @_;
		push @{$self->elts}, @elts;
	}

	sub length {
		my ($self, @elts) = @_;
		return scalar @{$self->elts};
	}

	sub nth {
		my ($self, $index) = @_;
		return $self->elts->[$index];
	}
}

1;
