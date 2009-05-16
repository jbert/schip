{
	package Schip::AST::Node;
	use Moose;

	has 'type'	=> (is => 'rw', isa => 'Str');
}

{
	package Schip::AST::Atom;
	use Moose;

	extends qw(Schip::AST::Node);
	has 'value'	=> (is => 'rw', isa => 'Str');
}

{
	package Schip::AST::List;
	use Moose;

	extends qw(Schip::AST::Node);
	has 'value'	=> (is			=> 'rw',
					isa			=> 'ArrayRef[Schip::AST::Node]',
					default		=> sub {[]}, );
}
1;
