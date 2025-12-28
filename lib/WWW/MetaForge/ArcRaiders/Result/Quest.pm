package WWW::MetaForge::ArcRaiders::Result::Quest;
# ABSTRACT: Quest result object

use Moo;
use Types::Standard qw(Str Int ArrayRef HashRef Maybe);
use namespace::clean;

has id => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has name => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has type => (
  is  => 'ro',
  isa => Maybe[Str],
);

has description => (
  is  => 'ro',
  isa => Maybe[Str],
);

has objectives => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  default => sub { [] },
);

has required_items => (
  is      => 'ro',
  isa     => ArrayRef[HashRef],
  default => sub { [] },
);

has rewards => (
  is      => 'ro',
  isa     => ArrayRef[HashRef],
  default => sub { [] },
);

has xp_reward => (
  is  => 'ro',
  isa => Maybe[Int],
);

has reputation_reward => (
  is  => 'ro',
  isa => Maybe[Int],
);

has next_quest => (
  is  => 'ro',
  isa => Maybe[Int],
);

has prev_quest => (
  is  => 'ro',
  isa => Maybe[Int],
);

has last_updated => (
  is  => 'ro',
  isa => Maybe[Str],
);

has _raw => (
  is  => 'ro',
  isa => HashRef,
);

sub from_hashref {
  my ($class, $data) = @_;
  return $class->new(
    id                => $data->{id},
    name              => $data->{name},
    type              => $data->{type},
    description       => $data->{description},
    objectives        => $data->{objectives} // [],
    required_items    => $data->{requiredItems} // [],
    rewards           => $data->{rewards} // [],
    xp_reward         => $data->{xpReward},
    reputation_reward => $data->{reputationReward},
    next_quest        => $data->{nextQuest},
    prev_quest        => $data->{prevQuest},
    last_updated      => $data->{lastUpdated},
    _raw              => $data,
  );
}

1;

=head1 SYNOPSIS

  my $quests = $api->quests(type => 'StoryQuest');
  for my $quest (@$quests) {
      say $quest->name;
      say "  " . $_ for $quest->objectives->@*;
  }

=head1 DESCRIPTION

Represents a quest from the ARC Raiders game.

=attr id

Quest identifier (string slug).

=attr name

Quest name.

=attr type

Quest type (e.g., "StoryQuest", "SideQuest").

=attr description

Quest description text.

=attr objectives

ArrayRef of objective strings.

=attr required_items

ArrayRef of required items: C<[{ item => "Name", quantity => 5 }]>.

=attr rewards

ArrayRef of rewards: C<[{ item => "Name", quantity => 1 }, { coins => 500 }]>.

=attr xp_reward

Experience points reward.

=attr reputation_reward

Reputation points reward.

=attr next_quest

ID of next quest in chain.

=attr prev_quest

ID of previous quest in chain.

=attr last_updated

ISO timestamp of last data update.

=method from_hashref

  my $quest = WWW::MetaForge::ArcRaiders::Result::Quest->from_hashref(\%data);

Construct from API response.

=cut
