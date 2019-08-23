#!/usr/bin/env perl

use 5.022;

# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
use Test::Exception;
use Data::Printer;
# use JSON::MaybeXS;
# use YAML::XS;
use feature qw /postderef signatures/;

# my $json = JSON::MaybeXS->new( utf8 => 1, pretty => 1 );

use Path::Tiny;

use Vote::Count;
use Vote::Count::Floor;
use Vote::Count::ReadBallots 'read_ballots';
use Vote::Count::Method::CondorcetVsIRV;

my $ballots_biggerset1 = read_ballots('t/data/biggerset1.txt');
my $ballots_smithirvunequal = read_ballots('t/data/irvdropsmithirvwinner.txt');

subtest 'simple set where irv winner and condorcet match' => sub {
  my $S1 =
  Vote::Count::Method::CondorcetVsIRV->new(
    'BallotSet' => $ballots_biggerset1,
  );
  my $winner1 =  $S1->CondorcetVsIRV() ;
  is( $winner1, 'MINTCHIP', 'check the winner');
  like( 
    $S1->logt(), 
    qr/Electing MINTCHIP the winner by both Condorcet and IRV/,
    'check logging for Electing ... the winner by both Condorcet and IRV'
    );
};


subtest 'edge case where regular irv drops smith irv winner' => sub {

  my $smithirvunequal = read_ballots('t/data/irvdropsmithirvwinner.txt');

  my $S2 =
    Vote::Count::Method::CondorcetVsIRV->new(
      'BallotSet' => $ballots_smithirvunequal,
    );


  my $S2smith =
    Vote::Count::Method::CondorcetVsIRV->new(
      'BallotSet' => $ballots_smithirvunequal,
      'TieBreakMethod' => 'grandjunction',
    );

  note $S2->CondorcetVsIRV( 'smithsetirv' => 0 );
  note $S2->logv();
  note $S2smith->CondorcetVsIRV( 'smithsetirv' => 1 );

  note( '*'x60, '*'x60);
  note $S2smith->logv();
  $S2smith->WriteLog();

  my $S2tca = Vote::Count::Method::CondorcetVsIRV->new(
      'BallotSet' => $ballots_smithirvunequal,
      'TieBreakMethod' => 'grandjunction',
    );
  my $S2floored =  $S2tca->TCA() ;
  $S2tca->SetActive($S2floored);
  note( "floored " . join( ' - ', ( keys $S2floored->%* )));
  my $S2tcarun = $S2tca->CondorcetVsIRV( 'smithsetirv' => 0 );
  is( $S2tcarun, 'VANILLA', 'apply tca floor before running with regalar irv.');

  ok 1;  
};
=pod


my $S2smith =
  Vote::Count::Method::CondorcetVsIRV->new(
    'BallotSet' => $biggerset1,
    'DropStyle' => 'all',
    'DropRule'  => 'topcount',
  );   
}
# p $S1;  

# my $winner1 =  $S1->SmithSetIRV() ;
# is( $winner1->{'winner'}, 'MINTCHIP', 'simple set with condorcet winner');


ok 1;

# my $S2 =
#   Vote::Count::Method::CondorcetVsIRV->new(
#     'BallotSet' => read_ballots('t/data/loop1.txt'),
#     'DropStyle' => 'all',
#     'DropRule'  => 'topcount',
#   );

# my $winner2 = $S2->SmithSetIRV() ;
# is( $winner2->{'winner'}, 'MINTCHIP', 'set with no condorcet winner');
# note $S2->logt;

# my $S3 =
#   Vote::Count::Method::CondorcetVsIRV->new(
#     'BallotSet' => read_ballots('t/data/ties1.txt'),
#     'DropStyle' => 'all',
#     'DropRule'  => 'topcount',
#   );

# my $result3 = $S3->SmithSetIRV() ;
# is( $result3->{'winner'}, 0, 'set that ends with a tie returns a false value winner');
# # my $tiechoices = { 'FUDGESWIRL', 1,'VANILLA',1};
# is_deeply( $result3->{'tied'}, ['FUDGESWIRL', 'VANILLA'],
#   'tied choices in $result->{tied}');
# note $S3->logv;
# p $S3->Active();
=cut

done_testing();
1;

=pod
subtest 'Plurality Loser Dropping (TopCount)' => sub {

my $M3 =
  Vote::Count::Method::CondorcetDropping->new(
    'BallotSet' => read_ballots('t/data/biggerset1.txt'),
    'DropStyle' => 'all',
    'DropRule'  => 'topcount',
  );
isa_ok( $M3, ['Vote::Count::Method::CondorcetDropping'],
  'ISA Vote::Count::Method::CondorcetDropping' );
my $rM3 = $M3->RunCondorcetDropping();
is ( $rM3->{'winner'}, 'MINTCHIP', 'winner for biggerset1 topcount/all');
note $M3->logv();

my $LoopSet =
  Vote::Count::Method::CondorcetDropping->new( 'BallotSet' => read_ballots('t/data/loop1.txt'),
  );
my $rLoopSet = $LoopSet->RunCondorcetDropping();
is( $rLoopSet->{'winner'}, 'MINTCHIP', 'loopset plurality leastwins winner');
note $LoopSet->logd();

my $LoopSetA =
  Vote::Count::Method::CondorcetDropping->new(
    'BallotSet' => read_ballots('t/data/loop1.txt'),
    'DropStyle' => 'all',
    'DropRule'  => 'topcount',
  );
my $rLoopSetA = $LoopSetA->RunCondorcetDropping();
is( $rLoopSetA->{'winner'}, 'MINTCHIP', 'loopset plurality leastwins winner is the same');
note $LoopSetA->logd();

my $KnotSet =
  Vote::Count::Method::CondorcetDropping->new(
    'BallotSet' => read_ballots('t/data/knot1.txt'),
  );

my $rKnotSet = $KnotSet->RunCondorcetDropping();
is( $rKnotSet->{'winner'}, 'CHOCOLATE', 'knotset winner with defaults');
note $KnotSet->logd();
};

subtest 'Approval Dropping' => sub {

note "********** LOOPSET *********";
my $LoopSet =
  Vote::Count::Method::CondorcetDropping->new(
  'BallotSet' => read_ballots('t/data/loop1.txt'),
    'DropStyle' => 'all',
    'DropRule'  => 'approval',
  );
my $rLoopSet = $LoopSet->RunCondorcetDropping();
is( $rLoopSet->{'winner'}, 'VANILLA', 'loopset approval all winner');
note $LoopSet->logd();
};

subtest 'Boorda Dropping' => sub {

note "\n********** LOOPSET BORDA *********";
my $LoopSetB =
  Vote::Count::Method::CondorcetDropping->new(
    'BallotSet' => read_ballots('t/data/loop1.txt'),
    'DropStyle' => 'leastwins',
    'DropRule'  => 'borda',
  );
my $rLoopSetB = $LoopSetB->RunCondorcetDropping();
is( $rLoopSetB->{'winner'}, 'MINTCHIP', 'loopset plurality leastwins winner is the same');
note $LoopSetB->logd();

note "\n********** KNOTSET BORDA *********";
my $KnotSet =
  Vote::Count::Method::CondorcetDropping->new(
    'BallotSet' => read_ballots('t/data/knot1.txt'),
    'DropStyle' => 'all',
    'DropRule'  => 'borda',
  );

my $rKnotSet = $KnotSet->RunCondorcetDropping();
is( $rKnotSet->{'winner'}, 'MINTCHIP', 'knotset winner with defaults');
note $KnotSet->logd();
};



done_testing();