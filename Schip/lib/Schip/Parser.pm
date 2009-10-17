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
            if (@list) {
                return Schip::AST::List->new(@list);
            }
            else {
                return Schip::AST::NilPair->new;
            }
		}
		when ('pair')	{
			my @pair = map { $self->_decorate_token_tree($_) } @$value;
			return Schip::AST::Pair->new(@pair);
		}
		# TODO - make these data driven to reduce repeated code?
		when ('qform') {
			$type = 'list';
			return Schip::AST::List->new(Schip::AST::Sym->new('quote'),
				$self->_decorate_token_tree($value));
		}
		when ('qqform') {
			$type = 'list';
			return Schip::AST::List->new(Schip::AST::Sym->new('quasiquote'),
				$self->_decorate_token_tree($value));
		}
		when ('uqform') {
			$type = 'list';
			return Schip::AST::List->new(Schip::AST::Sym->new('unquote'),
				$self->_decorate_token_tree($value));
		}
		when ('uqsform') {
			$type = 'list';
			return Schip::AST::List->new(Schip::AST::Sym->new('unquote-splicing'),
				$self->_decorate_token_tree($value));
		}
		when ('dotted_list') {
			$type = 'list';
			my @items = @{$value->[0]};
			push @items, $value->[1];
			@items = map { $self->_decorate_token_tree($_) } @items;
			my $cdr = pop @items;
			my $car = pop @items;
			warn "TODO: use pair ctor from list";
			my $return = Schip::AST::Pair->new($car, $cdr);
			while (@items) {
				$return = Schip::AST::Pair->new(pop @items, $return);
			}
			return $return;
		}
		default			{
			$ast_value = $value;
		}
	}
	$type	= "Schip::AST::" . ucfirst $type;
	return $type->new($ast_value);
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

symchar:			/[^.,@`;'"\s\(\)]/

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

dotted_list:		lparen mform(s?) '.' mform rparen
					{
#						print "hash: " . Data::Dumper::Dumper(\%item) . "\n";
#						print "list: " . Data::Dumper::Dumper(\@item) . "\n";
						$return = [ 'dotted_list', [ $item[2], $item[4] ] ];
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

form:				atom | pair | dotted_list | list
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
						$return = $item[2];
					}

forms:				mform(s)
};

1;

