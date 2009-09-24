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

	sub length {
		my $self = shift;
		return 1 + $self->cdr->length;
	}

	sub nth {
		my $self = shift;
		my $index = shift;

		if ($index == 0) {
			$self->car(@_) if @_;
			return $self->car;
		}
		return $self->cdr->nth($index-1, @_);
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

	sub foreach {
		my ($self, $func) = @_;
		$func->($self->car);
		return $self->cdr->foreach;
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

	sub length		{ 0; }
	sub nth			{ undef; }
	sub foreach		{ undef; }
}

{
	package Schip::AST::List;
	use base qw(Schip::AST::Node);
	# Two forms of representation, perl list of _elts or ref to a scheme cons list
	# we only ever have one form or the other
	__PACKAGE__->mk_accessors qw(_elts _clist);

	sub new {
		my ($class, @elts) = @_;
		return $class->SUPER::new({_elts => \@elts});
	}

	sub description { 'list'; }

	sub cdr {
		my $self = shift;
		$self->_break_to_clist if $self->_elts;
		return $self->_clist->cdr;
	}

	sub _break_to_clist {
		my $self = shift;
		die "Internal error: already a clist" if $self->_clist;
		my $clist = __PACKAGE__->_prepend_list_to_clist($self->_elts, Schip::AST::NilPair->new);
		$self->_clist($clist);
		$self->_elts(undef);
		return 1;
	}

	sub _prepend_list_to_clist {
		my ($class, $elts, $clist) = (@_);
		foreach my $elt (reverse @$elts) {
			$clist = Schip::AST::Pair->new($elt, $clist);
		}
		return $clist;
	}

	# ============================================================
	# Dual implementation elts/clist

	sub unshift {
		my ($self, @elts) = @_;
		if ($self->_elts) {
			unshift @{$self->_elts}, @elts;
		}
		else {
			my $clist = __PACKAGE__->_prepend_list_to_clist($self->_elts, $self->_clist);
			$self->_clist($clist);
		}
		return 1;
	}

	sub nth {
		my $self	= shift;
		my $index	= shift;
		my $val;
		if ($self->_elts) {
			if (@_) {
				$self->_elts->[$index] = shift;
			}
			$val = $self->_elts->[$index];
		}
		else {
			return $self->_clist->nth($index, @_);
		}
	}

	sub length {
		my ($self, @elts) = @_;
		if ($self->_elts) {
			return scalar @{$self->_elts};
		}
		else {
			return $self->_clist->length;
		}
	}

	sub foreach {
		my ($self, $func) = @_;
		if ($self->_elts) {
			$func->($_) for @{$self->_elts};
		}
		else {
			return $self->_clist->foreach($func);
		}
	}

	# ============================================================
	# Single implementation

	sub to_string {
		my ($self, $deparse) = @_;
		my $str;
		$self->foreach(sub {
			my $elt = shift;
			$str .= (defined $str ? ' ' : '(');
			$str .= $elt->to_string($deparse);
		});
		$str .= ')';
	}

	sub car			{ my $self = shift; return $self->nth(0, @_); }
	sub cadr		{ my $self = shift; return $self->nth(1, @_); }
	sub caddr		{ my $self = shift; return $self->nth(2, @_); }
	sub cadddr		{ my $self = shift; return $self->nth(3, @_); }
	sub caddddr		{ my $self = shift; return $self->nth(4, @_); }

	sub cddr		{ my $self = shift; return $self->cdr->cdr; }
	sub cdddr		{ my $self = shift; return $self->cdr->cdr->cdr; }
	sub cddddr		{ my $self = shift; return $self->cdr->cdr->cdr->cdr; }
	sub cdddddr		{ my $self = shift; return $self->cdr->cdr->cdr->cdr->cdr; }

}

1;
