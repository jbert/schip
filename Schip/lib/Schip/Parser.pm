package Schip::Parser;
use Moose;
use Schip::AST::Node;
use Text::ParseWords;
use 5.10.0;
use MooseX::NonMoose;

extends qw(Class::ErrorHandler);

sub parse {
	my $self		= shift;
	my $code_str	= shift;
	my @tokens = $self->_tokenize_string($code_str);
	return $self->errstr("NO_TOKENS") unless @tokens;

	return $self->_parse_one_form(\@tokens);
}

sub _parse_one_form {
	my $self	= shift;
	my $tokens	= shift;

	return $self->errstr("EMPTY_STREAM")
		unless scalar @$tokens;
	return $self->_parse_list($tokens) 
		if $tokens->[0] eq "(";
	return $self->_parse_atom(shift @$tokens);
}

sub _parse_list {
	my $self 	= shift;
	my $tokens	= shift;

	return $self->errstr("NO_LIST_START")
		unless $tokens->[0] eq '(';
	shift @$tokens;

	my @contents;
	LIST_ITEM:
	while (scalar @$tokens) {
		if ($tokens->[0] eq ')') {
			shift @$tokens;
			last LIST_ITEM;
		}
		push @contents, $self->_parse_one_form($tokens);
	}
	return Schip::AST::List->new(value => \@contents);
}

sub _parse_atom {
	my $self	= shift;
	my $token	= shift;
	my $type;
	given ($token) {
		when (/^\d+$/)		{ $type = 'Num' };
		when (/^\".*\"$/)	{ $type = 'Str' };
		default				{ $type = 'Sym' };
	}
	say "token [$token] is-a $type";
	$type = "Schip::AST::$type";
	return $type->new(value => $token);
}

sub _tokenize_string {
	my $self		= shift;
	my $code_str	= shift;

	my @raw_tokens = quotewords('\s+', 1, $code_str);
	return unless @raw_tokens;
	my @tokens;
	while (my $raw_token = shift @raw_tokens) {
		my ($start_parens, $token, $end_parens)
			= $raw_token =~ /^(\()*([^\)]*)(\))*$/;
		$start_parens	||= '';
		$end_parens		||= '';
		push @tokens, split(//, $start_parens), $token, split(//, $end_parens);
	}
	say "tokens are: " . join(":", @tokens);
	return @tokens;
}

1;
