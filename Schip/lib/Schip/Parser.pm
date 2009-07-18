package Schip::Parser;
use Moose;
use Schip::AST::Node;
use Text::ParseWords;
use 5.10.0;
use MooseX::NonMoose;

extends qw(Class::ErrorHandler);

{
	package Schip::Parser::Error;
	use Moose;
	has 'errstr'	=> (is => 'rw', isa => 'Str');
}

sub parse {
	my $self     = shift;
	my $code_str = shift;
	my $form;
	eval {
		use Data::Dumper;
		my $tokens = $self->_tokenize_string($code_str);
		$form = $self->_parse_one_form($tokens);
	};
	if ($@) {
		die("Parse failed: $@") unless UNIVERSAL::isa($@, 'Schip::Parser::Error');
		return $self->errstr($@->errstr);
	}
	return $form;
}


sub _die {
	my $self = shift;
	die Schip::Parser::Error->new(errstr => join(",", @_));
}

sub _parse_one_form {
	my $self        = shift;
	my $tokens        = shift;

	$self->_die("EMPTY_STREAM") unless scalar @$tokens;
	return $self->_parse_list($tokens) 
		if $tokens->[0] eq "(";
	return $self->_parse_quoted($tokens) 
		if $tokens->[0] eq "'";
	return $self->_parse_atom(shift @$tokens);
}

sub _parse_quoted {
	my $self         = shift;
	my $tokens        = shift;

	$self->_die("NO_QUOTE_START") unless $tokens->[0] eq "'";
	shift @$tokens;
	unshift @$tokens, "(", "quote";
	push    @$tokens, ")";
	return $self->_parse_list($tokens);
}

sub _parse_list {
	my $self         = shift;
	my $tokens        = shift;

	$self->_die("NO_LIST_START") unless $tokens->[0] eq '(';
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
	my $self        = shift;
	my $token        = shift;
	my $type;
	given ($token) {
		when (/^-?[\.\d]+$/)        { $type = 'Num' };
		when (/^\"(.*)\"$/)                { $type = 'Str';
		$token = $1   };
		default                                        { $type = 'Sym' };
	}
	$type = "Schip::AST::$type";
	return $type->new(value => $token);
}

sub _tokenize_string {
	my $self                = shift;
	my $code_str        = shift;

	my @raw_tokens = my_parse_line('\s+', 1, $code_str);
	$self->_die("NO_TOKENS") unless @raw_tokens;

	my @tokens;
RAW_TOKEN:
	while (defined (my $raw_token = shift @raw_tokens)) {
		next RAW_TOKEN unless defined $raw_token;
		my ($start_parens, $token, $end_parens)
			= $raw_token =~ /^
			(['\(]*)
			([^\)]*)
			(\)*)
			$/x;
		next RAW_TOKEN unless defined $token;
		$start_parens ||= '';
		$end_parens   ||= '';
		push @tokens, split(//, $start_parens);
		push @tokens, $token if defined $token && $token ne '';
		push @tokens, split(//, $end_parens);
	}
	$self->_die("NO_TOKENS") unless @tokens;
#        say "tokens are: " . join(", ", @tokens);
	return \@tokens;
}

# Ripped off from Text::ParseWords, but changed to be double-quotes only (since
# we want single quote for, well, quoting.
# TODO: write a proper parser.
sub my_parse_line {
    my($delimiter, $keep, $line) = @_;
    my($word, @pieces);

    no warnings 'uninitialized';	# we will be testing undef strings

    while (length($line)) {
        # This pattern is optimised to be stack conservative on older perls.
        # Do not refactor without being careful and testing it on very long strings.
        # See Perl bug #42980 for an example of a stack busting input.
        $line =~ s/^
                    (?: 
                        # double quoted string
                        (")                             # $quote
                        ((?>[^\\"]*(?:\\.[^\\"]*)*))"   # $quoted 
                    |   # --OR--
                        # unquoted string
						(                               # $unquoted 
                            (?:\\.|[^\\"])*?
                        )		
                        # followed by
						(                               # $delim
                            \Z(?!\n)                    # EOL
                        |   # --OR--
                            (?-x:$delimiter)            # delimiter
                        |   # --OR--                    
                            (?!^)(?=")               # a quote
                        )  
				    )//xs or return;				# extended layout                  

        my ($quote, $quoted, $unquoted, $delim) = ($1,$2,$3,$4);

		return() unless( defined($quote) || length($unquoted) || length($delim));

        if ($keep) {
		    $quoted = "$quote$quoted$quote";
		}
        else {
		    $unquoted =~ s/\\(.)/$1/sg;
		    if (defined $quote) {
				$quoted =~ s/\\(.)/$1/sg if ($quote eq '"');
            }
		}
        $word .= substr($line, 0, 0);	# leave results tainted
        $word .= defined $quote ? $quoted : $unquoted;
 
        if (length($delim)) {
            push(@pieces, $word);
            push(@pieces, $delim) if ($keep eq 'delimiters');
            undef $word;
        }
        if (!length($line)) {
            push(@pieces, $word);
		}
    }
    return(@pieces);
}



1;
