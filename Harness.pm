package Benchmark::Harness;
use Benchmark::Harness::Handler;
use strict;
use vars qw($VERSION $CVS_VERSION);
$VERSION = '1.09';
$CVS_VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 Benchmark::Harness

=head2 WARNING!

B<Connecting Benchmark::Harness to your Perl application can pose a serious
security/privacy risk to your application and the host computer it is running on.>

Under certain circumstances, the Harness allows an outside user to interject any
Perl process at any point in your host application. This can be done without access
to any of your source code or programs, tunnelling through any enveloping security
or privacy protections. The hacker can subvert any programmed security feature and,
with a little more effort, insert any Perl script into the context of your program,
and onto your host computer, at any point in your program.

No matter how innocuous your application is, through Benchmark::Harness it can be
made into a gateway to compromise the integrity of your entire host computer.

For this reason, basic authentication is built into Benchmark::Harness by default.
There is no default password. You must activate a user id and password in order
to make Benchmark::Harness work straight out of the box.
See the Authenticate() subroutine here in Benchmark::Harness to set up your initial userid/password.

B<I<DO NOT MAINTAIN A PERMANENT HOOK FOR Benchmark::Harness
IN YOUR PERL APPLICATION FOR ANY REASON!>>

=head2 SYNOPSIS

Benchmark::Harness will invoke subroutines at specific, parametizable
points during the execution of your Perl program.
These subroutines may be standard C<Benchmark::Harness> tracing routines, or routines composed by you.
The setup involves just a one line addition to your test or driver program,
and is easily parameterized and turned on or off from the outside.

To activate Benchmark::Harness on your program, add to your test or driver program the following:

  use Benchmark::Harness;
  Benchmark::Harness:new(userPsw, 'MyHarness(reportFilename, ...)', @parameters );

C<userPsw> is the required user authentication to make Benchmark::Harness work.
After authentication, new() loads your specified sub-harness (e.g., 'C<Benchmark::Harness::MyHarness>')
and executes the C<initialize()> method on it, giving it the parameters specified in parantheses here.
C<reportFilename> specifies how to report the results from your harness,
and C<@parameter> is a list of 'module::sub' strings, each of which specifies
a point in your target program to be monitored.

=over 4

=item userPsw

The first parameter must be the userid and password (in the form "userid:password").
There is no default for this, and until you make an adjustment in the Authenticate()
subroutine of Benchmark::Harness, the Benchmark::Harness will not function.

The base class will handle basic authentication in a standard manner for you, and you may override this
functionality by coding your own Authenticate() subroutine in your sub-harness.

=item 'MyHarness'

The second parameter causes your harness module to be loaded (you do not need to
'use' it to have it effective). See the documentation for C<Benchmark::Harness::Trace>
for how you would write your sub-harness.

Each sub-harness will be handed an array consisting of the parameters given in this new()
statement (as in the "(userPsw,...)" illustrated above).

=item reportFilename

Filename specifies the disposition (or not) of the output report.
Note that this is given to the sub-harness to handle as it pleases;
the base class Benchmark::Harness will handle it in the following manner:

=over 8

=item2 '1'

The harness report is written to a temporary file. You can get the string contained
in this file with the Benchmark::Harness::old() method. The temporary file is then deleted.

=item2 '0'

This is a convenient way to turn the harness off. Since it can be done by parameterization
from the outside, it is especially adaptable to external toggling of the harness.
If '0' is specified, no action is performed by Benchmark::Harness or by your sub-harness.

=item2 a file name

If not '1' or '0', then this parameter is interpreted as a filename into which the report
is written. C<Benchmark::Harness::old()> will now return this filename rather than the content
of the file. The report file will not be deleted by C<Benchmark::Harness::old()>.

=back

=back

=head3 Parameters

Benchmark::Harness handles subsequent parameters by calling SetupHandler() with them.
Your sub-harness may perform specialized operations with these parameters;
Benchmark::Harness's default behavior is as follows.

Each parameter after the filename specifies a sub() in your target program.
Methods in your sub-harness are called at the entry, exit, or both of the
C<sub()>s specified here.
These are strings; that is, you name the module and C<sub()> in a string, not by a CODE reference.

  my @parms = qw(-MyProgram::start +MyProgram::finish MyProgram::run)
  new Benchmark::Harness(userPsw, 'Benchmark::MyHarness(reportFilename)', @parms);

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

    new Benchmark::Harness(qw(user:psw Trace(1) -TestServer::M.* TestServer::Loop) )

traces the entry of every subroutine in C<TestServer> whose name begins with an 'M',
and the entry and exit of the subroutine C<Loop()>.

=head2 Example

    use Benchmark::Harness;
    my @traceParameters = qw(Trace(1) -TestServer::M.* TestServer::Loop);
    my $traceHarness = new Benchmark::Harness(userPsw, @traceParameters);

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
use Devel::Peek; # thanks to Nate and Tye on perlmonks.org . . .

## ###############################################
## Authenticate user:psw given as first parameter
sub Authenticate {
    my ($self, $givenAuthentication) = @_;

# NOTE: You must code the required user/psw in the form "userId:password".
my $Authentication = undef;
    return undef unless defined $Authentication;
    my ($rUserId, $rPassword) = split /\:/,$Authentication;
    my ($gUserId, $gPassword) = split /\:/,$givenAuthentication;
    return ($rUserId eq $gUserId) && ($rPassword eq $gPassword);
}

## #######################################################################
## Create a new harness based on the given sub-class of Benchmark::Harness
sub new {
    my $self = bless {
            '_startTime' => time()
           ,'_latestTime' => ''
           ,'_latestPackage' => ''
           ,'_latestFilename' => ''
           ,'_latestLine' => ''
        }, shift;
    my $authentication = shift;

    my ($harnessClass, $harnessParameters) = ($_[0] =~ m/^([^(]+)(?:\(([^)]*)\))?$/);
    $harnessClass = $_[0] unless $harnessClass; shift;

    bless $self, 'Benchmark::Harness::'.$harnessClass;
    eval 'use '.ref($self); die $@ if $@;

    my @harnessParameters = split /\|/, $harnessParameters;
    return $self unless $self->Authenticate($authentication); # pretend we're working, but we're not.

    $self->Initialize(@harnessParameters);
    $self->GenerateEvents(@_);

    # Now generate the harness attachment wrappers . . .
    map {$_->Attach($self)} @{$self->{EventList}};

    # We're ready to go, print the report header.
    $self->harnessPrintReportHeader();
    $self->{_latestTime} = $self->{_startTime};

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

# Overridable by event handler
sub harnessPrintReportHeader {
    my ($self) = @_;
    my $fh = $self->{_outFH};
    my $tm = localtime;
    my $tagName = ref($self); $tagName =~ s{^.*::([^:]+)$}{$1};# $tagName =~ s/::/:/g;
    my $version = $self->VERSION;
    print $fh "<$tagName ".$self->xmlHeaders." n='$0' v='$version' V='$VERSION' tm='$tm' pid='$$' userid='$<,$>' os='$^O'>";
    map {print $fh "<ID id='$_->[Benchmark::Harness::Handler::ID]' name='$_->[Benchmark::Harness::Handler::NAME]' type='method' package='$_->[Benchmark::Harness::Handler::PACKAGE]' modifiers='$_->[Benchmark::Harness::Handler::MODIFIERS]'/>"}
        @{$self->{EventList}};
}

# Overridable by event harness
sub harnessPrintReportFooter {
    my $fh = $_[0]->{_outFH};
    my $tagName = ref($_[0]); $tagName =~ s{^.*::([^:]+)$}{$1}; #$tagName =~ s/::/:/g;
    print $fh "</$tagName>";
}

# Generic $harness->print
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
    $self->harnessPrintReportFooter();
    close $fh;
    delete $self->{_outFH};

    map { $_->Detach() } @{$self->{EventList}};
    delete $self->{EventList};
    return $self;
}

DESTROY {
  $_[0]->close();
}

### ###########################################################################
### FindHandler(newHandler) -
sub FindHandler {
    my ($self, $pckg, $subName) = @_;
    for ( @{$self->{EventList}} ) {
        if ( $_->[Benchmark::Harness::Handler::NAME] eq $subName
          && $_->[Benchmark::Harness::Handler::PACKAGE] eq $pckg
        ) {
            return $_;
        }
    }
    return undef;
}

### ###########################################################################
sub harnessPrintReport {
    my $self = ref($_[0])?shift:$Benchmark::Harness::Harness;
    return unless ref($self);
    my ($mode,$trace) = @_;

    my $rpt = $self->{report};
    return unless $rpt;

    my $fh = $self->{_outFH};
    return unless $fh;

    print $fh '<'.(defined($rpt->[0])?$rpt->[0]:'T')." _i='$trace->{id}' _m='$mode'";
    my $closeTag = '/>';

    my $hsh = $rpt->[1];
    map { print $fh " $_='$hsh->{$_}'" } keys %$hsh;

    if ( defined $rpt->[2] ) {
        print $fh '>'; $closeTag = '</'.(defined($rpt->[0])?$rpt->[0]:'T').'>';
        for ( @{$rpt->[2]} ) {

        }
    }

    if ( defined $rpt->[3] ) {
        print $fh '>'; $closeTag = '</'.(defined($rpt->[0])?$rpt->[0]:'T').'>';
        print $fh $rpt->[3];
    }

    print $fh $closeTag;
    $self->{report} = undef;
}

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
  my $obj = $_[0];

  my $objName = "$obj";
  $objName =~ s{=?(ARRAY|HASH|SCALAR).*$}{};
  my $objType = $1;
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
  my $obj = shift;

  my $objName = "$obj";
  $objName =~ s{=?([A-Z]+).*$}{};#s{=?(ARRAY|HASH|SCALAR|CODE).*$}{};
  my $objType = $1 || '';

  if ( $objType eq 'HASH' ) {
    my $i = 0;
    for ( keys %$obj ) {
      my $obj = ref($_)?$_:\$_;
      my ($nm) = ($_);
      $nm = $i unless $nm; $i += 1;
      $self->print("<V n='$nm'/>");
    }
  } elsif ( $objType eq 'ARRAY' ) {
        my $i = 0;
        for ( @$obj ) {
        my ($nm) = ($i);
        $i += 1;
        $self->print("<V n='$nm'/>");
        last if ( ++$i == 20 );
        if ( scalar(@$objType) > 20 ) {
            $self->print("<G n='".scalar(@_)."'/>");
        };
    }
  } elsif ( $objType eq 'SCALAR' ) {
      $self->print("<V>$$obj</V>");
  } else {
      $self->print("<V t='$objType'>$obj</V>");
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
sub xmlHeaders {
#?? '<?xml version="1.0" encoding="UTF-8"?>'        ??
#?? '<?xml version="1.0" encoding="ISO-8859-1"?>'   ??
  my $pckg = ref($_[0]);
  $pckg =~ s{Benchmark\:\:Harness\:\:}{};
  $pckg =~ s{::}{/}g;
  #my $schema = "http://schemas.GlennWood.us/Benchmark/$pckg";
  #my $hdr = " xmlns='$schema'";
  my $hdr .= " xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'";
  $hdr .= " xsi:noNamespaceSchemaLocation='http://schemas.benchmark-harness.org/$pckg.xsd'";#" xsi:schemaLocation='$schema\nhttp://schemas.benchmark-harness.org/$pckg.xsd'";
  return $hdr;
}

### ###########################################################################
### ###########################################################################
# HERE WE SET UP THE DEFAULT BASE METHODS FOR CERTAIN STATISTICS
sub Initialize { # stub - this is normally set up in event handler
    my $self = shift;

    for ( @_ ) {
        m/^0?$/ && do { return $self; }; # '0' shuts everything off. next; };
        m/^\|\d/ && do {
                $self->{_isHotpipe} = 1;
                $_ =~ s/^\|//;
            }; # then fall through to tempfile open
        m/^\d+$/ && do {
                $self->{_outFilename} = (($^O eq 'MSWin32')?$ENV{TEMP}:'/tmp').'/harness.'.$$.'.xml';
                $self->{_outFH} = new FileHandle(">$self->{_outFilename}")
                        or die "Can't open Harness file '$self->{_outFilename}': $!";
                $self->{_isTemp} = 1;
                $self->{_outFH}->autoflush(1) if ( $self->{_isHotpipe} );;
                next;
            };
        m/^\|./ && do {
                $self->{_isHotpipe} = 1;
                $_ =~ s/^\|//;
            }; # then fall through to filename open
        m/^./ && do {
                $self->{_outFilename} = $_;
                $self->{_outFH} = new FileHandle(">$self->{_outFilename}")
                       or die "Can't open Harness file '$self->{_outFilename}': $!";
                $self->{_isTemp} = 0;
                $self->{_outFH}->autoflush(1) if ( $self->{_isHotpipe} );;
                next;
            };
        }
    return $self;
}

### ###########################################################################
### ###########################################################################
#
sub GenerateEvents {
    my $self = shift;
    $self->{EventList} = [];
    my $handler = ref($self); $handler =~ s{(\:\:[\w\d]+)$}{::Handler$1};

    for ( @_ ) {
        my ($modifiers, $pckg, $method) = (m/^(?:\(([^)]*)\))?(.*)::([^:]+)$/);
        eval "require $pckg"; die $@ if $@;
        if ( $method !~ m/[\.\?\*\[\(]/ ) {
            $handler->new($self, $modifiers, $pckg, $method);
        } else {
            # thanks to Nate on perlmonks.org . . .
            no strict;
            local *stash;
            *stash = *{ "${pckg}::" };
            local $rgx = qr($method);
            for (keys %stash)
            {
                my $glob = Devel::Peek::CvGV(\&{$stash{$_}});
                $handler->new($self, $modifiers, $pckg, $_)
                    if ( defined &{ $stash{$_} }
                        and $glob eq "\*$pckg\:\:$_"
                        and m/$rgx/
                        and !m/(import|export|AUTOLOAD)/ );
            }
        }
    }
    return 1;
}
1;

__END__

=head2 CHANGES

$Log: Harness.pm,v $
Revision 1.2  2004/11/04 08:24:00  Administrator
Benchmark::Harness v1.08

Revision 1.1  2004/11/02 07:51:41  Administrator
Contact Info

Revision 1.5  2004/09/29 22:11:33  woodg
reoganized - into Benchmark/Harness/(Trace|MemoryUsage)

Revision 1.4  2004/09/29 21:17:20  woodg
Trace, and wildcard method selection!

Revision 1.3  2004/09/03 23:43:46  woodg
Benchmark::Harness sub-classing

Revision 1.2  2004/09/03 19:55:29  woodg
some POD

=head1 AUTHOR

Glenn Wood, <glennwood@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2004 Glenn Wood. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
