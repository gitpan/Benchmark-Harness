package Benchmark::Harness::Trace;
use Benchmark::Harness;
use base qw(Benchmark::Harness);
use strict;
use vars qw($VERSION); $VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);


=pod

=head1 Benchmark::Harness::Trace

=head2 SYNOPSIS

(stay tuned . . . )

=cut


sub new {
  bless new Benchmark::Harness(@_);
}
### ###########################################################################
# USAGE: Benchmark::Trace::MethodArguments('class::method', [, 'class::method' ] )
sub onSubEntry {
  my $self = shift;
  my $origMethod = shift;

  my $i=0;
  for ( \@_ ) {
    $self->NamedObject("Entry($origMethod)",$_);
  }
  return @_; # return the input arguments unchanged.
}

### ###########################################################################
# USAGE: Benchmark::Trace::MethodReturn('class::method', [, 'class::method' ] )
sub onSubExit {
  my $self = shift;
  my $origMethod = shift;

  if (wantarray) {
    my $i=0;
    for ( @_ ) {
      $self->NamedObject("Exit($origMethod)",$_);
    }
    #($self->NamedObject("wantarray Exit($origMethod)=".ref($answer),$answer));
    return @_; # return the result array unchanged
  } else {
    my $answer = shift;
    scalar $self->NamedObject("Exit($origMethod)",$answer);
    return $answer; # return the result scalar unchanged
  }
}


### ###########################################################################

1;