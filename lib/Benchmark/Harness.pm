package Benchmark::Harness;
use strict;
use vars qw($VERSION); $VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 Benchmark::Harness

=head2 SYNOPSIS

Benchmark::Harness will invoke subroutines at specific, parametizable
points during the execution of your Perl program.
These subroutines may be standard C<Benchmark::Harness> tracing routines, or routines composed by you.
The setup involves just a one line addition to your test or driver program,
and is easily parameterized and turned on or off from the outside.

To activate Benchmark::Harness on your program, add to your test or driver program the following:

  use Benchmark::Harness;
  Benchmark::Harness:new('MyHarness', $filename, @parameters );

This loads your self-composed harness (e.g., 'C<Benchmark::Harness::MyHarness>'; C<$filename> specifies how to report the results
from your harness, and C<@parameter> is a list of 'module::sub' strings, each of which specifies
a point in your target program to be monitored.

=over 4

=item 'MyHarness'

The first parameter causes your harness module to be loaded (you do not need to
'use' it to have it effective). See the documentation for C<Benchmark::Harness::Trace>
for how you would write your sub-harness.

=item Filename

Filename specifies the disposition (or not) of the output report.

=over 8

=item '1'

The harness report is written to a temporary file. You can get the string contained
in this file with the Benchmark::Harness::old() method. The temporary file is then deleted.

=item '0'

This is a convenient way to turn the harness off. Since it can be done by parameterization
from the outside, it is especially adaptable to external toggling of the harness.
If '0' is specified, no action is performed by Benchmark::Harness or by your sub-harness
(your sub-harness is not even loaded).

=item a file name

If not '1' or '0', then this parameter is interpreted as a filename into which the report
is written. C<Benchmark::Harness::old()> will now return this filename rather than the content
of the file. The report file will not be deleted by C<Benchmark::Harness::old()>.

=back

=back

=head3 Parameters

Each parameter after the filename specifies a sub() in your target program.
Methods in your sub-harness are called at the entry, exit, or both of the
C<sub()>s specified here.
These are strings; that is, you name the module and C<sub()> in a string, not by a CODE reference.

  my @parms = qw(-MyProgram::start +MyProgram::finish MyProgram::run)
  Benchmark::Harness::new('Benchmark::MyHarness', $filename, @parms);

Each parameter is preceded by a special character to specify the type of
monitoring to be performed on that sub().

=over 4

=item '-'

Your sub-harness is called at the entry of the target sub(), with @_ equal
to the input parameters of that sub().

=item '+'

Your sub-harness is called when the sub() exits, with @_ or $_[0] (depending on wantarray)
equal to the return value of that sub().

=item none

Performs both '-' and '+'.

=back

You may select subroutines from your target module by some simple wildcards
(which are actually Perl regular expressions). Thus,

    new Benchmark::Harness( qw(Trace 1 -TestServer::M.* TestServer::Loop) )

traces the entry of every subroutine in C<TestServer> whose name begins with an 'M',
and the entry and exit of the subroutine C<Loop()>.

=head2 Example

    use Benchmark::Harness;
    my @traceParameters = qw(Trace 1 -TestServer::M.* TestServer::Loop);
    my $traceHarness = new Benchmark::Harness(@traceParameters);

    TestServer::new(5,10,15,3,4);   # Fire the module under test,

    my $result = $traceHarness->old(); # and here's our result (ref to a string).

See C<Benchmark::Harness::Trace> and C<Benchmark::Harness::MemoryUsage> for examples
of how to build your own harness operations.

=head2 More generalization

Use the following construction to generalize your harness cababilites even more.
It is especially adaptable to supplying harness parameters in an XML attribute
(as an xsd:list type, which is a space delimited string).

  my @harnessParameters = split /\s/, $myParameterString;
  if ( @harnessParameters ) {
    eval "use Benchmark::Harness";
    my $harness = Benchmark::Harness::new(\@harnessParameters);
  }

=cut

use FileHandle;
use Time::HiRes;
use Devel::Peek; # thanks to Nate and Tye on perlmonks.org . . .

my $Harness;



#############################################
# Use this filename if need to write a temp.
use vars qw($BenchmarkXmlTempFilename);
$BenchmarkXmlTempFilename = '/tmp/benchmark_harness_$$.tmp';
$BenchmarkXmlTempFilename = 'C:/TEMP/benchmark_harness_$$.tmp' if $^O eq 'MSWin32';
#############################################

sub new {
  my $self = bless {
          '_startTime' => Time::HiRes::time()
         ,'_latestTime' => ''
         ,'_latestPackage' => ''
         ,'_latestFilename' => ''
         ,'_latestLine' => ''
      }, shift;
    bless $self, 'Benchmark::Harness::'.shift;
    return $self if $_[0] eq '0'; # '0' shuts everything off.
    eval "use ".ref($self);

    my $isHarness = undef;
    my @harnessParameters = shift @_;
    for ( @_ ) {
        my ($traceType, $origMethod) = (m/^([-+*]?)(.*)$/);
        my ($pckg, $method) = ($origMethod =~ m/^(.*)::([^:]*)$/);
        eval "require $pckg"; die $@ if $@;
#        if ( $method !~ m/[\.\?\*\[\(]/ ) {
#            push @harnessParameters, $_;
#        } else
        {   # thanks to Nate on perlmonks.org . . .
            no strict;
            local *stash;
            *stash = *{ "${pckg}::" };
            local $rgx = qr($method);
            for (keys %stash)
            {
               my $glob = Devel::Peek::CvGV(\&{$stash{$_}});
               $glob =~ s/^\*//;
               push (@harnessParameters, $pckg.'::'.$_) if defined &{ $stash{$_} }
                  and $glob eq "$pckg\:\:$_" and m/$rgx/;
            }
        }
    }
    for ( @harnessParameters ) {
        if ( $isHarness ) {
            my ($traceType, $origMethod) = (m/^([-+*]?)(.*)$/);
            if ( $traceType eq '-' ) { # monitor the arguments?
                $self->MethodArguments($origMethod);
            }
            elsif ( $traceType eq '+' ) { # monitor the return?
                $self->MethodReturn($origMethod);
            }
            elsif ( $traceType eq '*' ) { # monitor arguments and return?
                $self->MethodArgumentsAndReturn($origMethod);
            }
            else { # default - monitor arguments and return.
                $self->MethodArgumentsAndReturn($_);
            }
        } else {
            m/^0?$/ && do { next; };
            m/^\d+$/ && do {
                    $self->{_outFilename} = "$BenchmarkXmlTempFilename";
                    $self->{_outFH} = new FileHandle(">$self->{_outFilename}")
                            or die "Can't open Harness file '$self->{_outFilename}': $!";
                    $self->{_isTemp} = 1;
                    $isHarness = $self;
                    #my $fh = $self->{_outFH}; select $fh; $| = 1; select STDOUT;
                    next;
                };
            m/^./ && do {
                    $self->{_outFilename} = $_;
                    $self->{_outFH} = new FileHandle(">$self->{_outFilename}")
                           or die "Can't open Harness file '$self->{_outFilename}': $!";
                    $self->{_isTemp} = 0;
                    $isHarness = $self;
                    next;
                };
        }
    }

  my $tm = localtime;
  my $tagName = ref($self); $tagName =~ s{^.*::([^:]+)$}{$1};# $tagName =~ s/::/:/g;
  $self->print("<$tagName ".$self->xmlHeaders." n='$0' tm='$tm' pid='$$' userid='$<,$>' os='$^O'>");

  $self->{_latestTime} = $self->{_startTime};
  $Benchmark::Harness::Harness = $self;

  return $self;
}

sub old {
  my $self = ref($_[0])?shift:$Benchmark::Harness::Harness;
  return unless ref($self);
  $self->close if $self->{_outFH};

  if ( $self->{_isTemp} ) {
        open TMP, "<$self->{_outFilename}" or die "Can't open Harness file '$self->{_outFilename}': $!";
        my $value= join '',<TMP>; close TMP;
        unlink $self->{_outFilename}; # would be unlinked by Apache::TempFile.
        delete $self->{_outFilename};
        return \$value;
  } else {
    return $self->{_outFilename};
  }
}

sub print {
  my $self = ref($_[0])?shift:$Benchmark::Harness::Harness;
  return unless ref($self);
  my $fh = $self->{_outFH};
  return unless $fh;
  print $fh $_[0];
  return $self;
}

sub close {
  my $self = ref($_[0])?shift:$Benchmark::Harness::Harness;
  return unless ref($self);
  my $fh = $self->{_outFH};
  return unless $fh;
  my $tagName = ref($self); $tagName =~ s{^.*::([^:]+)$}{$1}; #$tagName =~ s/::/:/g;
  print $fh "</$tagName>";
  close $fh;
  delete $self->{_outFH};
  return $self;
}

DESTROY {
  $_[0]->close();
}

### ###########################################################################
sub _PrintT {
  my ($self, $n, $p, $f, $l) = @_;

  $self->print("<T");

  my $tm = Time::HiRes::time() - $self->{_startTime};
  if ( $self->{_latestTime} ne $tm ) {
    $self->{_latestTime} = $tm;
    $self->print(" t='$self->{_latestTime}'");
  }
  if ( defined $p && ($self->{_latestPackage} ne $p) ) {
    $self->{_latestPackage} = $p;
    $self->print(" p='$self->{_latestPackage}'");
  }
  if ( $self->{_latestFilename} ne $f ) {
    $self->{_latestFilename} = $f;
    $self->print(" f='$self->{_latestFilename}'");
  }
  if ( $self->{_latestLine} ne $l ) {
    $self->{_latestLine} = $l;
    $self->print(" l='$self->{_latestLine}'");
  }

  my $siz;
  if ( $^O eq 'MSWin32' ) {
    my $ps = eval "Win32::Process::Info->new";
    if ( $ps ) {
        my @info = $ps->GetProcInfo( $$ );
        $siz = $info[0]->{'WorkingSetSize'}/1024;
    } else {
        $siz = 'no Win32::Process::Info';
    }
  } else {
    $siz = `ps -o rss= -p $$`;
  }
  $self->print(" ps='$siz'");

  if ( $n ) {
    $self->print(" n='$n'");
  }

  $self->print(">");
}
sub _PrintT_ { $_[0]->print("</T>"); }

### ###########################################################################
# USAGE: Harness::Variables(list of any variable(s));
sub Variables {
  my $self = ref($_[0])?shift:$Benchmark::Harness::Harness;
  return unless ref($self);
  return unless $self->{_outFH};
}


### ###########################################################################
# USAGE: Harness::Arguments(@_);
sub Arguments {
  my $self = ref($_[0])?shift:$Benchmark::Harness::Harness;
  return $self unless ref($self);
  return $self unless $self->{_outFH};

  $self->_PrintT('-Arguments', caller(1));

  my $i = 1;
  for ( @_ ) {
    my $obj = ref($_)?$_:\$_;
    my ($nm, $sz) = (ref($_), Devel::Size::total_size($_));
    $nm = $i unless $nm; $i += 1;
    $self->print("<V n='$nm' s='$sz'/>");
  }
  $self->_PrintT_();
  return $self;
}

### ###########################################################################
# USAGE: Harness::NamedObject($name, $self); - where $self is a blessed reference.
sub NamedObject {
  my $self = ref($_[0])?shift:$Benchmark::Harness::Harness;
  return $self unless ref($self);
  return $self unless $self->{_outFH};
  my $name = shift;
  my $pckg = $_[0];

  my $pckgName = "$pckg";
  $pckgName =~ s{=?(ARRAY|HASH|SCALAR).*$}{};
  my $pckgType = $1;
  $self->_PrintT($name, caller(1));
  $self->OnObject(@_);

  $self->_PrintT_();
  return $self;
}

### ###########################################################################
# USAGE: Harness::Object($self); - where $self is a blessed reference.
sub Object {
  my $self = ref($_[0])?shift:$Benchmark::Harness::Harness;
  return $self unless ref($self);
  return $self unless $self->{_outFH};
  my $pckg = $_[0];

  my $pckgName = "$pckg";
  $pckgName =~ s{=?(ARRAY|HASH|SCALAR).*$}{};
  my $pckgType = $1;
  $self->_PrintT("-$pckgType $pckgName", caller(1));
  $self->OnObject(@_);

  $self->_PrintT_();
  return $self;
}

### ###########################################################################
# USAGE: Benchmark::MemoryUsage::MethodReturn( $pckg )
#     Print useful information about the given object ($pckg)
sub OnObject {
  my $self = shift;
  my $pckg = shift;

  my $pckgName = "$pckg";
  $pckgName =~ s{=?([A-Z]+).*$}{};#s{=?(ARRAY|HASH|SCALAR|CODE).*$}{};
  my $pckgType = $1 || '';

  my $i = 1;
  if ( $pckgType eq 'HASH' ) {
    for ( keys %$pckg ) {
      my $obj = ref($_)?$_:\$_;
      my ($nm) = ($_);
      $nm = $i unless $nm; $i += 1;
      $self->print("<V n='$nm'/>");
    }
  } elsif ( $pckgType eq 'ARRAY' ) {
    for ( @$pckg ) {
      my ($nm) = ($i);
      $i += 1;
      $self->print("<V n='$nm'/>");
    }
  } elsif ( $pckgType eq 'SCALAR' ) {
      my ($nm) = ($i);
      $i += 1;
      $self->print("<V n='$nm'/>");
  } else {
      my ($nm) = ($i);
      $i += 1;
      $self->print("<V n='$nm' t='$pckgType'/>");
  }
  return $self;
}

### ###########################################################################
# USAGE: Harness::NamedVariables('name1' => $variable1 [, 'name1' => $variable2 ])
sub NamedVariables {
  my $self = ref($_[0])?shift:$Benchmark::Harness::Harness;
  return $self unless ref($self);
  return $self unless $self->{_outFH};

  $self->_PrintT(undef, caller(1));

  my $i = 1;
  while ( @_ ) {
    my ($nm, $sz) = (shift, Devel::Size::total_size(shift));
    $nm = $i unless $nm; $i += 1;
    $self->print("<V n='$nm' s='$sz'/>");
  }
  $self->_PrintT_();
  return $self;
}

### ###########################################################################
# USAGE: Harness::NamedVariables('name1' => $variable1 [, 'name1' => $variable2 ])
sub Trace {
  my $self = ref($_[0])?shift:$Benchmark::Harness::Harness;
  return $self unless ref($self);
  return $self unless $self->{_outFH};

  $self->_PrintT(undef, caller(1));

  my $i = 1;
  while ( @_ ) {
    $self->print('<t><![CDATA['.shift(@_).']]></t>');
  }
  $self->_PrintT_();
  return $self;
}

### ###########################################################################
# USAGE: Benchmark::Harness::MethodArguments('class::method', [, 'class::method' ] )
sub MethodArguments {
  my $traceSelf = ref($_[0])?shift:$Benchmark::Harness::Harness;
  return $traceSelf unless ref($traceSelf);

  for my $origMethod ( @_ ) {
    if ( !$traceSelf->{_HarnessedMethods}->{$origMethod} ) {
        $traceSelf->{_HarnessedMethods}->{$origMethod} = \&$origMethod;
        my ($pckg, $method) = ($origMethod =~ m/^(.*)::([^:]*)$/);

        # Strangely, $traceSelf is still in scope even when the following eval'd
        #   sub is executed! (though nothing else seems to be) - gdw.2004.09.02
        my $newMethod = <<EOT;
{package $pckg; # override $origMethod - $pckg\:\:$method
sub $method {
    my \@newArgs = \$traceSelf->onSubEntry('$origMethod', \@_);
    goto \$traceSelf->{_HarnessedMethods}->{'$origMethod'};
}1;
}
EOT
        no warnings;
        eval $newMethod;
        Benchmark::Harness::Trace("eval FAILED on:\n$newMethod\n$@") if $@;
    }
  }
  return $traceSelf;
}

### ###########################################################################
# USAGE: Benchmark::Harness::MethodReturn('class::method', [, 'class::method' ] )
sub MethodReturn {
  my $traceSelf = ref($_[0])?shift:$Benchmark::Harness::Harness;
  return $traceSelf unless ref($traceSelf);

  for my $origMethod ( @_ ) {
    if ( !$traceSelf->{_HarnessedMethods}->{$origMethod} ) {
        $traceSelf->{_HarnessedMethods}->{$origMethod} = \&$origMethod;
        my ($pckg, $method) = ($origMethod =~ m/^(.*)::([^:]*)$/);

        # Strangely, $traceSelf is still in scope even when the following eval'd
        #   sub is executed! (though nothing else seems to be) - gdw.2004.09.02
        my $newMethod = <<EOT;
{package $pckg; # override $origMethod - $pckg\:\:$method
sub $method {
    if (wantarray) {
      my \@answer = \$traceSelf->{_HarnessedMethods}->{'$origMethod'}(\@_);
      return (\$traceSelf->onSubExit('$origMethod', \@answer));
    } else {
      my \$answer = \$traceSelf->{_HarnessedMethods}->{'$origMethod'}(\@_);
      return scalar \$traceSelf->onSubExit('$origMethod', \$answer);
    }
}1;
}
EOT
        no warnings;
        eval $newMethod;
        Benchmark::Harness::Trace("eval FAILED on:\n$newMethod\n$@") if $@;
    }
  }
  return $traceSelf;
}

### ###########################################################################
# USAGE: Benchmark::Harness::MethodArgumentsAndReturn('class::method', [, 'class::method' ] )
sub MethodArgumentsAndReturn {
  my $traceSelf = ref($_[0])?shift:$Benchmark::Harness::Harness;
  return $traceSelf unless ref($traceSelf);

  for my $origMethod ( @_ ) {
    next unless $origMethod;
    if ( !$traceSelf->{_HarnessedMethods}->{$origMethod} ) {
        $traceSelf->{_HarnessedMethods}->{$origMethod} = \&$origMethod;
        my ($pckg, $method) = ($origMethod =~ m/^(.*)::([^:]*)$/);

        # Strangely, $traceSelf is still in scope even when the following eval'd
        #   sub is executed! (though nothing else seems to be) - gdw.2004.09.02
        my $newMethod = <<EOT;
{package $pckg; # override $origMethod - $pckg\:\:$method
sub $method {
    my \@newArgs = \$traceSelf->onSubEntry('$origMethod', \@_);
    if (wantarray) {
      my \@answer = \$traceSelf->{_HarnessedMethods}->{'$origMethod'}(\@_);
      return (\$traceSelf->onSubExit('$origMethod', \@answer));
    } else {
      my \$answer = \$traceSelf->{_HarnessedMethods}->{'$origMethod'}(\@_);
      return scalar \$traceSelf->onSubExit('$origMethod', \$answer);
    }
}1;
}
EOT
        no warnings;
        eval $newMethod;
        Benchmark::Harness::Trace("eval FAILED on:\n$newMethod\n$@") if $@;
    }
  }
  return $traceSelf;
}

### ###########################################################################
# USAGE: Benchmark::MemoryUsage::MethodArguments('class::method', [, 'class::method' ] )
sub onSubEntry {
return;
  my $self = shift;
  my $origMethod = shift;

  my $i=0;
  for ( \@_ ) {
    $self->NamedObject("Entry($origMethod)\\n".$i++.','.ref($_),$_);
  }
  return @_; # return the input arguments unchanged.
}

### ###########################################################################
# USAGE: Benchmark::MemoryUsage::MethodReturn('class::method', [, 'class::method' ] )
sub onSubExit {
  my $self = shift;
  my $origMethod = shift;

  my $answer = shift;
  if (wantarray) {
    ($self->NamedObject("Exit($origMethod)",$answer));
    return @$answer; # return the result array unchanged
  } else {
    scalar $self->NamedObject("Exit($origMethod)",$answer);
    return $answer; # return the result scalar unchanged
  }
}

### ###########################################################################

sub xmlHeaders {
  my $pckg = ref($_[0]);
  $pckg =~ s{::}{}g;
  #my $schema = "http://schemas.GlennWood.us/Benchmark/$pckg";
  #my $hdr = " xmlns='$schema'";
  my $hdr .= " xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'";
  $hdr .= " xsi:noNamespaceSchemaLocation='../xsd/$pckg.xsd'";#" xsi:schemaLocation='$schema\n../xsd/Benchmark$pckg.xsd'";
  return $hdr;
}
1;

__END__

=head2 CHANGES

$Log: Harness.pm,v $
Revision 1.5  2004/09/29 22:11:33  woodg
reoganized - into Benchmark/Harness/(Trace|MemoryUsage)

Revision 1.4  2004/09/29 21:17:20  woodg
Trace, and wildcard method selection!

Revision 1.3  2004/09/03 23:43:46  woodg
Benchmark::Harness sub-classing

Revision 1.2  2004/09/03 19:55:29  woodg
some POD

=head1 COPYRIGHT

(c) 2004 Yahoo, Inc.

=head1 AUTHOR

Glenn Wood <Glenn.Wood@Oveture.com>

=cut
