package Schip::Evaluator::Primitive;
use Moose;
use Moose::Autobox;

use List::MoreUtils qw(all);
use List::Util qw(sum);

has 'code'	=> (is => 'ro', isa => 'CodeRef');

extends qw(Schip::Evaluator::Invokable);

sub invoke {
	my $self = shift;
	my $args = shift;
	return $self->code->($args);
}

sub install {
	my $class = shift;
	my $env   = shift;

	# TODO: write in terms of fold, and make generic
	# TODO: this wants to be a class, with helpers

	my $die_unless_type = sub {
		my $type		= shift;
		my $prim		= shift;
		my $args		= shift;

		my $class = "Schip::AST::$type";
		my @wrong_type = grep { !$_->isa($class) } @$args;
		if (@wrong_type) {
			my $err = "Non-" . $class->description . " argument(s) to $prim: "
				. join(", ", map { $_->value } @wrong_type);
			die_error($err);
		};
	};

	my $plus = Schip::Evaluator::Primitive->new(
		code => sub {
			my $args = shift;
			$die_unless_type->('Num', '+', $args);
			my $sum = sum map { $_->value } @$args;
			return Schip::AST::Num->new(value => $sum);
		}
	);
	$env->push_frame('+' => $plus);

	my $error = Schip::Evaluator::Primitive->new(
		code => sub {
			my $args = shift;
			die_error("Error called with > 1 arg") if @$args > 1;
			$die_unless_type->('Str', 'error', $args);
			my ($str) = map { $_->value } @$args;
			$str //= "Unspecified error";
			die_error($str);
		}
	);
	$env->push_frame('error' => $error);

	my $list = Schip::Evaluator::Primitive->new(
		code => sub {
			my $args = shift;
			return Schip::AST::List->new(value => $args);
		}
	);
	$env->push_frame('list' => $list);

	my $cons = Schip::Evaluator::Primitive->new(
		code => sub {
			my $args = shift;
			die_error("cons called with != 2 args") if @$args != 2;
			my $car = $args->[0];
			my $cdr = $args->[1];
			# Consing with a list in cdr gives you a list
			if ($cdr->isa('Schip::AST::List')) {
				return Schip::AST::List->new(value => [$car, @{$cdr->value}]);
			}
			else {
				return Schip::AST::Pair->new(value => [$car, $cdr]);
			}
		}
	);
	$env->push_frame('cons' => $cons);

	my $car = Schip::Evaluator::Primitive->new(
		code => sub {
			my $args = shift;
			die_error("car called with != 1 args")	if @$args != 1;
			die_error("car called on non-pair: " . ref $args->[0])
				unless $args->[0]->isa('Schip::AST::Pair');
			my $list = $args->[0];
			# Controversial?
			die "car of empty list" if $list->value->length == 0;
			return $list->value->[0];
		}
	);
	$env->push_frame('car' => $car);

	my $cdr = Schip::Evaluator::Primitive->new(
		code => sub {
			my $args = shift;
			die_error("cdr called with != 1 args")	if @$args != 1;
			die_error("car called on non-pair: " . ref $args->[0])
				unless $args->[0]->isa('Schip::AST::Pair');
			my $list = $args->[0];
			die "cdr of empty list" if $list->value->length == 0;
			if ($list->value->length == 1) {
				# Should we have a global, static object for the null list?
				return Schip::AST::List->new(value => []);
			}
			else {
				# Symettric to conditional in cons.
				if ($list->isa('Schip::AST::List')) {
					my @newlist = @{$list->value};
					shift @newlist;
					return Schip::AST::List->new(value => \@newlist);
				}
				elsif ($list->isa('Schip::AST::Pair')) {
					return $list->value->[1];
				}
				else {
					die_error("Unknown type in cdr: " . ref($list->value));
				}
			}
			return $list->value->[0];
		}
	);
	$env->push_frame('cdr' => $cdr);

	# TODO - pull to seperate module
#	use Math::BigRat;
#	my $divide = Schip::Evaluator::Primitive->new(
#		code => sub {
#			my $args = shift;
#			$die_unless_type->('Num', '+', $args);
#			my @arg_nums = map { $_->value } @$args;
#			my $result = Math::BigRat->new(shift @arg_nums);
#			while (@arg_nums) {
#				my $arg = shift @arg_nums;
#				die_error("Division by zero") unless $arg;
#				$result /= $arg;
#			}
#			return Schip::AST::Num->new(value => $result->bstr);
#		}
#	);
#	$env->push_frame('/' => $divide);

	return $env;
}

sub die_error {
	my $error_str = shift;
	die Schip::Evaluator::Error->new(info => $error_str);
}

1;
