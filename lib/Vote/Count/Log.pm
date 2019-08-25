use strict;
use warnings;
use 5.022;

use feature qw /postderef signatures/;

package Vote::Count::Log;
use Moose::Role;

no warnings 'experimental';
use Path::Tiny 0.108;
# use Data::Printer;


our $VERSION='0.021';

=head1 NAME

Vote::Count::Log

=head1 VERSION 0.021

=cut

# ABSTRACT: Logging for Vote::Count. Toolkit for vote counting.

=head1 Definition of Approval

In Approval Voting, voters indicate which Choices they approve of indicating no preference. Approval can be infered from a Ranked Choice Ballot, by treating each ranked Choice as Approved.

=head1 Method Approval

Returns a RankCount object for the current Active Set taking an optional argument of an active list as a HashRef.

  my $Approval = $Election->Approval();
  say $Approval->RankTable;

=cut

has 'LogTo' => (
  is => 'lazy',
  is => 'rw',
  isa => 'Str',
  builder => '_logsetup',
);

has 'LogPath' => (
  is => 'rw',
  isa => 'Str',
  default => '/tmp',  
);

has 'LogBaseName' => (
  is => 'rw',
  isa => 'Str',
  default => 'votecount'
);

sub _logsetup ( $self ) {
  my $pathBase = $self->{'LogPath'} || '/tmp';
  $pathBase =~ s/\/$|\\$//; # trim \ or / from end.
  unless ( stat $pathBase ) {
    path( $pathBase)->mkpath();
  }
  my $baseName = $self->{'LogBaseName'} || 'votecount' ;
  return "$pathBase/$baseName";
}

sub logt {
  my $self = shift @_;
  return $self->{'LogT'} unless ( @_) ;
  my $msg = join( "\n", @_ ) . "\n";
  $self->{'LogT'} .= $msg;
  $self->{'LogV'} .= $msg;
  $self->logd( @_);
}

sub logv {
  my $self = shift @_;
  return $self->{'LogV'} unless ( @_) ;
  my $msg = join( "\n", @_ ) . "\n";
  $self->{'LogV'} .= $msg;
  $self->logd( @_);
}

sub logd {
  my $self = shift @_;
  return $self->{'LogD'} unless ( @_) ;
  my @args = (@_);
  # since ops are seqential and fast logging event times
  # clutters the debug log.
  # unshift @args, localtime->date . ' ' . localtime->time;
  my $msg = join( "\n", @args ) . "\n";
  $self->{'LogD'} .= $msg;
}

sub WriteLog {
  my $self = shift @_;
  my $logroot = $self->LogTo();
  path( "$logroot.brief")->spew( $self->logt() );
  path( "$logroot.full")->spew( $self->logv() );
  path( "$logroot.debug")->spew( $self->logd() );
}


1;

#FOOTER

=pod

BUG TRACKER

L<https://github.com/brainbuz/Vote-Count/issues>

AUTHOR

John Karr (BRAINBUZ) brainbuz@cpan.org

CONTRIBUTORS

Copyright 2019 by John Karr (BRAINBUZ) brainbuz@cpan.org.

LICENSE

This module is released under the GNU Public License Version 3. See license file for details. For more information on this license visit L<http://fsf.org>.

=cut

