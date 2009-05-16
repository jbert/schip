package Schip::Env;
use Moose;
use Moose::Autobox;

has '_frames'	=> (
	is			=> 'rw',
	isa			=> 'ArrayRef[HashRef]',
	default		=> sub{[]},
	);

sub frame_depth {
	my $self = shift;
	return $self->_frames->length;
}

sub pop_frame {
	my $self = shift;
	$self->_frames->pop;
}

sub push_frame {
	my $self = shift;
	my %frame = @_;
	$self->_frames->unshift(\%frame);
}

sub lookup {
	my $self = shift;
	my $symbol = shift;
	foreach my $frame (@{$self->_frames}) {
		return $frame->{$symbol} if exists $frame->{$symbol};
	}
	return undef;
}

sub clone {
	my $self = shift;
	my $clone = __PACKAGE__->new;
	# Shallow copy of frames, to work when we take a closure
	# (We don't currently allow set!, if/when we do allow mutable
	# frames, should we deep copy or not?)
	$clone->_frames([ @{$self->_frames} ]);
	return $clone;
}

1;
