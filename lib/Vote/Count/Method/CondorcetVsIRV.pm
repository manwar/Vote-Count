use strict;
use warnings;
use 5.022;
use feature qw /postderef signatures/;

package Vote::Count::Method::CondorcetVsIRV;
use namespace::autoclean;
use Moose;
extends 'Vote::Count::Method::CondorcetIRV';

# use Exporter::Easy ( EXPORT => [ 'CondorcetVsIRV' ] );

# use Vote::Count;
# use Vote::Count::Method::CondorcetIRV;
use Storable 3.15 'dclone';
use Vote::Count::ReadBallots qw/read_ballots write_ballots/;
use Vote::Count::Redact qw/RedactSingle RedactPair RedactBullet/;
use Try::Tiny;

our $VERSION='0.021';

# no warnings 'uninitialized';
no warnings qw/experimental/;

=head1 NAME

Vote::Count::Method::CondorcetVsIRV

=head1 VERSION 0.021

=cut

# ABSTRACT: Condorcet versus IRV

=pod

=head1 SYNOPSIS

  use Vote::Count::Method::CondorcetVsIRV;

  ...

=head1 Method Common Name: Condorcet vs IRV

Determine if the Condorcet Winner needed votes from the IRV winner, elect the Condorcet Winner if there was not a later harm violation, elect the IRV winner if there was.

The method looks for a Condorcet Winner, if there is none it uses IRV to find the winner. If there is a Condorcet Winner it uses standard IRV to find the IRV winner. It then copies the ballots and redacts the later choice from those ballots that indicated both. It then determines if one of the two choices is a Condorcet Winner, if not it determines if one of them would win IRV. If either choice is the winner with redacted ballots, they win. If neither wins, the Condorcet Winner dependended on a Later Harm effect against the IRV winner, and the IRV Winner is elected.

The relaxed later harm option, when neither choice wins the redacted ballots, takes the greatest loss by the Condorcet Winner in the redacted matrix and compares it to their margin of victory over the IRV winner. If the victory margin is greater the Condorcet Winner is elected.

=head2 Implementation

Details specific to this implementation. 

CondorcetVsIRV applies the TCA Floor Rule.

An important implementation detail is that CondorcetVsIRV uses Smith Set IRV where possible. The initial election for a Condorcet Winner uses this, providing the IRV Winner should there be no Condorcet Winner. If there is a Condorcet Winner, the Redaction election uses Smith Set IRV. The only time it isn't used is conducting IRV after finding a Condorcet Winner in the initial test.

It was chosen to use the TCA (Top Count vs Approval) Floor Rule because it cannot eliminate any 'Winable Alternatives' (by either Condorcet or IRV), but it is aggressive at eliminating non-winable alternatives which should improve the Consistency of IRV.

Smith Set IRV is used whenever possible because it also eliminates non-winable alternatives from IRV, and it is already alternating between Condorcet and IRV.

The tie breaker is defaulted to (modified) Grand Junction for resolvability.

=head2 Function Name: CondorcetVsIRV

CondorcetVsIRV is exported.

  my $Election = Vote::Count->new( ... );
  my $winner = CondorcetVsIRV( $Election );
  or
  my $winner = CondorcetVsIRV( $Election, relaxed => 1 );

# options -- smithset -- active


=head2 Criteria

=head3 Simplicity

This is a medium complexity method. It builds on simpler methods but has a significant number of steps and branches. 

=head3 Later Harm

This method meets Later Harm with the default strict option. Using the TCA

The relaxed option allows a finite Later Harm effect.

=head3 Condorcet Criteria

This method only meets Condorcet Loser, when the IRV winner is chosen of the Condorcet Winner, the winner is outside the Smith Set. 
Meets Condorcer Winner, Condorcet Loser, and Smith.

=head3 Consistency

Because this method chooses between the outcomes of two different methods, it inherits the consistency failings of both. It should improve overall the Clone Handling versus IRV, because in cases where the winnable clone loses IRV, it may be the Condorcet Winner.

=cut

has 'LogTo' => (
  is => 'rw',
  isa => 'Str',
  default => '/tmp/condorcetvsirv',
);

has 'LogRedactedTo' => ( 
  is => 'lazy',
  is => 'rw',
  isa => 'Str',
  builder => '_setredactedlog',
);

sub _setredactedlog ( $self ) { 
  # There is a bug with LogTo being uninitialized despite having a default
  my $logto  = defined $self->LogTo()
    ? $self->LogTo() . '_redacted'
    : '/tmp/condorcetvsirv_redacted' ; 
  return $logto ;
}

sub ResetActive ( $self ) { return dclone $self->BallotSet()->{'choices'} }

sub _CVI_IRV ( $I, $active, $smithsetirv ) {  
  my $WonIRV = undef;
  my $irvresult = undef;

warn "cvi irv smithset flag is $smithsetirv ==========="  ;
  if ($smithsetirv) {

# smithirv needs to match irv args.
warn "smithsetirv requested ============" ;
    $irvresult = $I->SmithSetIRV( $I->TieBreakMethod() );  
  } else {
warn "normal irv requested ============" ;    
    $irvresult = $I->RunIRV( $active, $I->TieBreakMethod() );
  }
  return $irvresult->{'winner'} if $irvresult->{'winner'};
  $I->logt( "Aborting Election. IRV ended with a Tie.");
  $I->logt( "Active (Tied) Choices are: " . join( ', ', $irvresult->{'tied'}));
  $I->SetActiveFromArrayRef( $irvresult->{'tied'});
  return 0;
}

sub _CVI_RedactRun ( $E, $A, $B, %options ) {
  # my $RedactedBallots =  Vote::Count::Matrix->new( 
  #   'BallotSet' =>
  #    RedactPair( $E->BallotSet(), $A, $B, 'Active' => $options->{'active'} );
}

sub CondorcetVsIRV ( $E, %args ) {
  my $relaxed = defined $args{'relaxed'} ? 1 : 0 ;
  my $smithsetirv = defined $args{'smithsetirv'} ? $args{'smithsetirv'} : 0 ;
  my $active = defined $args{'active'} ? $args{'active'} : $E->Active();
  # check for majority winner.
  my $majority = $E->EvaluateTopCountMajority()->{'winner'};
  return $majority if $majority ;
  my $WonIRV = undef;
  my $WonCondorcet = $E->PairMatrix()->CondorcetWinner();

  if ($WonCondorcet) {
    $E->logt( "Condorcet Winner is $WonCondorcet");
    # Even if SmithSetIRV requested, it would return the condorcet winner
    # We need to know if a different choice would win IRV.
    $WonIRV = $E->RunIRV( $active, $E->TieBreakMethod() )->{'winner'};
  } else {
    $E->logt( "No Condorcet Winner" );
    $WonIRV = $E->_CVI_IRV( $active, $smithsetirv );
  }

  # IRV private already logged tie, now return the false value.
  # Edge case IRV tie with Condorcet Winner, I guess CW wins?
  unless ( $WonIRV ) {
    if ($WonCondorcet) { 
      $E->logt( "Electing Condorcet Winner $WonCondorcet, IRV tied.");
      return $WonCondorcet ;
    }
    return 0; 
  }
  if ( $WonIRV eq $WonCondorcet ) { 
    $E->logt( "Electing $WonIRV the winner by both Condorcet and IRV.");
    return $WonIRV;
  }
  if ( $WonIRV and !$WonCondorcet ) { 
    $E->logt( "Electing IRV Winner $WonIRV. There was no Condorcet Winner.");
    return $WonIRV;
  }  
  $E->logt( "reached end without a decision IRV Winner $WonIRV Condorcet Winner $WonCondorcet This is where redacted ballots are needed.");
  return 0;
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
