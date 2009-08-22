package Schip::Parser;
use Moose;
use Schip::AST::Node;
use 5.10.0;
use Parse::RecDescent;
use MooseX::NonMoose;

extends qw(Class::ErrorHandler);

{
	package Schip::Parser::Error;
	use Moose;
	has 'errstr'	=> (is => 'rw', isa => 'Str');
}

$::RD_HINT=1;
$Parse::RecDescent::skip = '';
my $SCHEME_GRAMMAR;

sub parse {
	my $self     = shift;
	my $code_str = shift;

#	say 'code is: ' . $code_str;
	my $parser = Parse::RecDescent->new($SCHEME_GRAMMAR);
	my $token_trees = $parser->forms($code_str);
	return unless $token_trees;
#	use Data::Dumper;
#	say 'tokens : ' . Dumper($token_trees);

	my @forms;
	eval {
		push @forms, $self->_decorate_token_tree($_) for @$token_trees;
	};
	if ($@) {
		die("Parse failed: $@") unless UNIVERSAL::isa($@, 'Schip::Parser::Error');
		return $self->errstr($@->errstr);
	}
	return wantarray ? @forms : $forms[0];
}

sub _decorate_token_tree {
	my ($self, $token_tree) = @_;
	my ($type, $value) = @$token_tree;

	my $ast_value;
	given ($type) {
		when ('list')	{
			my @list = map { $self->_decorate_token_tree($_) } @$value;
			$ast_value = \@list;
		}
		when ('pair')	{
			my @pair = map { $self->_decorate_token_tree($_) } @$value;
			$ast_value = \@pair;
		}
		# TODO - make these data driven to reduce repeated code?
		when ('qform') {
			$type = 'list';
			$ast_value = [Schip::AST::Sym->new(value => 'quote'), $self->_decorate_token_tree($value)];
		}
		when ('qqform') {
			$type = 'list';
			$ast_value = [Schip::AST::Sym->new(value => 'quasiquote'), $self->_decorate_token_tree($value)];
		}
		when ('uqform') {
			$type = 'list';
			$ast_value = [Schip::AST::Sym->new(value => 'unquote'), $self->_decorate_token_tree($value)];
		}
		when ('uqsform') {
			$type = 'list';
			$ast_value = [Schip::AST::Sym->new(value => 'unquote-splicing'), $self->_decorate_token_tree($value)];
		}
		default			{
			$ast_value = $value;
		}
	}
	$type	= "Schip::AST::" . ucfirst $type;
	return $type->new(value => $ast_value);
}


$SCHEME_GRAMMAR = q{

dquote:				'"'
escaped_dquote:		'\"'
notdquote:			/[^"]/
dquoted_elt:		escaped_dquote | notdquote

str:				dquote dquoted_elt(s?) dquote
					{
						$return = [$item[0], join('', @{$item[2]})];
					}

lparen:				'('
rparen:				')'

whitespace:			/\s+/
comment:			/;.*\n/
spacelike:			whitespace | comment

symchar:			/[^,@`;'"\s\(\)]/

digit:				/\d/
sign:				/\+|-/

decimalpt:			'.'
decimalexpansion:	decimalpt digit(s)
					{
						$return = $item[1] . join('', @{$item[2]});
					}

num:				sign(?) digit(s) decimalexpansion(?)
					{
						my $rule = shift @item;
						my $numstr = '';
						$numstr .= join('', @{$_}) for @item;
						$return = [ $rule, $numstr ];
					}

sym:				symchar(s)
					{
						$return = [$item[0], join("", @{$item[1]})];
					}

atom:				str | num | sym
					{
						$return = $item[1];
					}

list:				lparen mform(s?) spacelike(?) rparen
					{
#						print "hash: " . Data::Dumper::Dumper(\%item) . "\n";
#						print "list: " . Data::Dumper::Dumper(\@item) . "\n";
						$return = [ $item[0], [ @{$item{'mform(s?)'}} ] ];
					}

pair:				lparen mform '.' mform rparen
					{
#						print "hash: " . Data::Dumper::Dumper(\%item) . "\n";
#						print "list: " . Data::Dumper::Dumper(\@item) . "\n";
						$return = [ $item[0], [ $item[2], $item[4] ] ];
					}

form:				(atom | pair | list)
					{ $return = $item[1]; }

quote:				/'/
qform:				quote form
					{
						$return = [ $item[0], $item[2] ];
					}
quasiquote:			'`'
qqform:				quasiquote form
					{
						$return = [ $item[0], $item[2] ];
					}
unquote:			','
uqform:				unquote form
					{
						$return = [ $item[0], $item[2] ];
					}
unquote_splice:		',@'
uqsform:			unquote_splice form
					{
						$return = [ $item[0], $item[2] ];
					}


mform:				spacelike(?) (form | uqsform | uqform | qqform | qform) spacelike(?)
					{
					use Data::Dumper;
						$return = $item[2];
					}

forms:				mform(s)
};

1;

