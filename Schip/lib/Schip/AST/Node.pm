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
    sub is_null { 0; }
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
		my $self = $class->SUPER::new({car => $car, cdr => $cdr});
		return $self;
	}

	sub length {
		my $self = shift;
		return unless $self->is_list;
		return 1 + $self->cdr->length;
	}

	sub nth {
		my $self = shift;
		my $index = shift;
		return unless $self->is_list;

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
		my $hide_dot = $self->cdr->is_pair;
		$ret .= '(' unless $parent_hid_dot;
		$ret .= $car->to_string($deparse);
        $ret .= ' ' unless $cdr->is_null;
		$ret .= '. ' unless $hide_dot;
		$ret .= $cdr->to_string($deparse, $hide_dot) unless $cdr->is_null;
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
		return unless $self->is_list;
		$func->($self->car);
		return $self->cdr->foreach($func);
	}

	sub map {
		my ($self, $func, $skip) = @_;
		$skip //= 0;
		return unless $self->is_list;
		if ($skip > 0) {
			return $self->cdr->map($func, $skip - 1);
		}
		else {
			return ($func->($self->car), $self->cdr->map($func));
		}
	}

    sub is_list {
        my $self = shift;
        return $self->cdr->is_list;
    }

    sub is_pair { 1; }
    sub is_null { 0; }

    sub make_list {
        my ($class, @contents) = @_;
        my $list = Schip::AST::NilPair->new;
        foreach my $elt (reverse @contents) {
            $list = Schip::AST::Pair->new($elt, $list);
        }
        return $list;
    }

    sub cadr    { $_[0]->cdr->car; }
    sub cddr    { $_[0]->cdr->cdr; }
    sub caddr   { $_[0]->cdr->cdr->car; }
    sub cdddr   { $_[0]->cdr->cdr->cdr; }
    sub cadddr  { $_[0]->cdr->cdr->cdr->car; }
    sub cddddr  { $_[0]->cdr->cdr->cdr->cdr; }
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
    sub is_list     { 1; }
    sub is_null     { 1; }
}

1;
