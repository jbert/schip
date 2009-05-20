{
	package Schip::AST::Node;
	use Moose;

	has 'type'	=> (is => 'rw', isa => 'Str');
}

{
	package Schip::AST::Atom;
	use Moose;

	extends qw(Schip::AST::Node);
}

{
	package Schip::AST::Num;
	use Moose;

	extends qw(Schip::AST::Atom);
	has 'value'	=> (is => 'rw', isa => 'Num');

	sub to_string {
		my $self = shift;
		return $self->value;
	}
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
}

{
	package Schip::AST::Str;
	use Moose;

	extends qw(Schip::AST::Atom);
	has 'value'	=> (is => 'rw', isa => 'Str');

	sub to_string {
		my $self = shift;
		my $val = $self->value;
		if ($val =~ /^\d+$/) {
			return $val;
		}
		else {
			return '"' . $self->_escape_quotes . '"';
		}
	}

	sub _escape_quotes {
		my $self = shift;
		my $str  = shift || $self->value;
		$str =~ s/\\/\\\\/g;
		$str =~ s/"/\\"/g;
		return $str;
	}
}

{
	package Schip::AST::List;
	use Moose;
	use Moose::Autobox;

	extends qw(Schip::AST::Node);
	has 'value'	=> (is			=> 'rw',
					isa			=> 'ArrayRef[Schip::AST::Node]',
					default		=> sub {[]}, );

	sub to_string {
		my $self = shift;
		return "(" . $self->value->map(sub {$_->to_string})->join(" ") . ")";
	}
}
1;
