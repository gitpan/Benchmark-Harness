package Benchmark::Harness::MemoryUsage;
use Benchmark::Harness;
use base qw(Benchmark::Harness);
use strict;
use vars qw($VERSION); $VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 Benchmark::Harness::MemoryUsage

=head2 SYNOPSIS

(stay tuned . . . )

=cut

use Devel::Size;

BEGIN {
  eval "use Win32::Process::Info" if $^O eq 'MSWin32';
}

sub new {
  bless new Benchmark::Harness(@_);
}
### ###########################################################################
# USAGE: Benchmark::MemoryUsage::MethodArguments('class::method', [, 'class::method' ] )
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
# USAGE: Benchmark::MemoryUsage::MethodReturn('class::method', [, 'class::method' ] )
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
# USAGE: Benchmark::MemoryUsage::MethodReturn( $pckg )
#     Print memory usage of the given object ($pckg)
sub OnObject {
  my $self = shift;
  my $pckg = shift;

  my $pckgName = "$pckg";
  $pckgName =~ s{=?(ARRAY|HASH|SCALAR).*$}{};
  my $pckgType = $1;

  my $i = 1;
  if ( $pckgType eq 'HASH' ) {
    for ( keys %$pckg ) {
      my $obj = ref($_)?$_:\$_;
      my ($nm, $sz) = ($_, Devel::Size::total_size($pckg->{$_}));
      $nm = $i unless $nm; $i += 1;
      $self->print("<V n='$nm' s='$sz'/>");
    }
  } elsif ( $pckgType eq 'ARRAY' ) {
    for ( @$pckg ) {
      my ($nm, $sz) = ($i, Devel::Size::total_size($pckg->[$i]));
      $i += 1;
      $self->print("<V n='$nm' s='$sz'/>");
    }
  } elsif ( $pckgType eq 'SCALAR' ) {
      my ($nm, $sz) = ($i, Devel::Size::total_size($pckg));
      $i += 1;
      $self->print("<V n='$nm' s='$sz'/>");
  } else {
      my ($nm, $sz) = ($i, Devel::Size::total_size($pckg));
      $i += 1;
      $self->print("<V n='$nm' s='$sz'/>");
  }
  return $self;
}

### ###########################################################################

1;