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
	my $form;
	eval {
		my $tokens = $self->_tokenize_string($code_str);
		$form = $self->_parse_one_form($tokens);
	};
	if ($@) {
		return $self->errstr($@);
	}
	return $form;
}

sub _parse_one_form {
	my $self	= shift;
	my $tokens	= shift;

	die "EMPTY_STREAM" unless scalar @$tokens;
	return $self->_parse_list($tokens) 
		if $tokens->[0] eq "(";
	return $self->_parse_atom(shift @$tokens);
}

sub _parse_list {
	my $self 	= shift;
	my $tokens	= shift;

	die "NO_LIST_START" unless $tokens->[0] eq '(';
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
		when (/^-?[\.\d]+$/)	{ $type = 'Num' };
		when (/^\".*\"$/)		{ $type = 'Str' };
		default					{ $type = 'Sym' };
	}
	$type = "Schip::AST::$type";
	return $type->new(value => $token);
}

sub _tokenize_string {
	my $self		= shift;
	my $code_str	= shift;

	my @raw_tokens = quotewords('\s+', 1, $code_str);
	die "NO_TOKENS" unless @raw_tokens;
	my @tokens;
	RAW_TOKEN:
	while (defined (my $raw_token = shift @raw_tokens)) {
		next RAW_TOKEN unless defined $raw_token;
		my ($start_parens, $token, $end_parens)
			= $raw_token =~ /^
							(\(*)
							([^\)]*)
							(\)*)
							$/x;
		next RAW_TOKEN unless defined $token;
		$start_parens	||= '';
		$end_parens		||= '';
		push @tokens, split(//, $start_parens), $token, split(//, $end_parens);
	}
	die "NO_TOKENS" unless @tokens;
	return \@tokens;
}

1;
