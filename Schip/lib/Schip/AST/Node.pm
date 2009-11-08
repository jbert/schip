use strict;
use warnings;
use 5.10.0;
use Carp;
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
		Carp::croak "Too many args to new $class" unless @_ == 2;
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
		return ref $self eq ref $rhs && $$self eq $$rhs;
	}

    sub is_list { 0; }
    sub is_pair { 0; }
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


=pod 

...ok. wtf do we do about lists
    . is it ok that an empty s.ast.list has-a _clist which is the nilpair?
    . should NilPair == the empty list instead?
    . s.ast.list should be an implementation detail in the ast tree

=cut

{
	package Schip::AST::Pair;
	use base qw(Schip::AST::Node);
	__PACKAGE__->mk_accessors qw(car is_clist);

	sub new {
		my ($class, $car, $cdr) = @_;
		my $self = $class->SUPER::new({car => $car});
        $cdr->break_to_clist if $cdr->isa('Schip::AST::List');
		$self->cdr($cdr);	# Sets is_clist too
		return $self;
	}

	sub length {
		my $self = shift;
		return unless $self->is_clist;
		return 1 + $self->cdr->length;
	}

	sub cdr {
		my $self = shift;
		if (@_) {
			my $val = shift;
			my $is_clist = ($val->isa('Schip::AST::Pair')
                         || $val->isa('Schip::AST::List')) && $val->is_clist;
			$self->is_clist($is_clist);
			$self->{cdr} = $val;
		}
		return $self->{cdr}
	}

	sub nth {
		my $self = shift;
		my $index = shift;
		return unless $self->is_clist;

		if ($index == 0) {
			$self->car(@_) if @_;
			return $self->car;
		}
		return $self->cdr->nth($index-1, @_);
	}

	sub to_string {
		my ($self, $deparse, $parent_hid_dot) = @_;
		my ($car, $cdr) = ($self->car, $self->cdr);
		my $ret = '';
		my $hide_dot = $self->cdr->isa('Schip::AST::Pair') || $self->cdr->isa('Schip::AST::List');
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
		return unless $self->is_clist;
		$func->($self->car);
		return $self->cdr->foreach($func);
	}

	sub map {
		my ($self, $func, $skip) = @_;
		$skip //= 0;
		return unless $self->is_clist;
		if ($skip > 0) {
			return $self->cdr->map($func, $skip - 1);
		}
		else {
			return ($func->($self->car), $self->cdr->map($func));
		}
	}

    sub is_list {
        my $self = shift;
        return $self->is_clist;
    }
    sub is_pair { 1; }
}

{
	package Schip::AST::NilPair;
	use base qw(Schip::AST::Pair);

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
	sub map			{ (); }
	sub is_clist	{ 1; }
    sub is_list     { 1; }
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
		$self->break_to_clist;
		return $self->_clist->cdr;
	}

	sub break_to_clist {
		my $self = shift;
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
		Carp::cluck "What to return?" if $index > ($self->length-1);
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

	sub map {
		my ($self, $func, $skip) = @_;
		$skip //= 0;
		if ($self->_elts) {
			my @elts = @{$self->_elts};
			return () unless @elts;
			return map { $func->($_); } @elts[$skip..$#elts];
		}
		else {
			return $self->_clist->map($func, $skip);
		}
	}

	# ============================================================
	# Single implementation

    sub is_list { 1; }
    # The hierarchy is a bit broken here. ::List should really be is-a ::Pair
    # (a pair is something which provides the car+cdr methods)
    sub is_pair { 1; }
    sub is_clist {
        my $self = shift;
        return defined $self->_clist;
    }

	sub to_string {
		my ($self, $deparse, $parent_hid_dot) = @_;
		my $str = '';
		$str .= '(' unless $parent_hid_dot;
		$self->foreach(sub {
			my $elt = shift;
			$str .= $elt->to_string($deparse);
			$str .= ' ';
		});
		$str =~ s/ $//;
		$str .= ')' unless $parent_hid_dot;
		return $str;
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
