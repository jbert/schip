{
	package Schip::AST::Node;
	use Moose;

	has 'type'	=> (is => 'rw', isa => 'Str');

	sub description { die "Abstract node doesn't have a description"; }

	sub equals		{ die "Abstract node can't compare for equality"; }

	# Most forms string representation is the same as their deparse
	sub deparse	{
		my $self = shift;
		return $self->to_string;
	}
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
		my $self = shift;
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
		my $self = shift;
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
		my $self = shift;
		return $self->value;
	}

	sub deparse {
		my $self = shift;
		my $val = $self->value;
		return '"' . $self->_escape_quotes . '"';
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

	sub to_string {
		my $self = shift;
		return "(" . $self->value->[0]->to_string . " . " . $self->value->[1]->to_string . ")";
	}

	sub deparse {
		my $self = shift;
		return "(" . $self->value->[0]->deparse . " . " . $self->value->[1]->deparse . ")";
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

	sub deparse {
		my $self = shift;
		return "(" . $self->value->map(sub {$_->deparse})->join(" ") . ")";
	}

	sub to_string {
		my $self = shift;
		return "(" . $self->value->map(sub {$_->to_string})->join(" ") . ")";
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
}

1;
