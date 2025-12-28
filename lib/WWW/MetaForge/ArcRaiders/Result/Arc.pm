package WWW::MetaForge::ArcRaiders::Result::Arc;
# ABSTRACT: Arc (mission/event) result object

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

has maps => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  default => sub { [] },
);

has duration => (
  is  => 'ro',
  isa => Maybe[Int],
);

has cooldown => (
  is  => 'ro',
  isa => Maybe[Int],
);

has loot => (
  is      => 'ro',
  isa     => ArrayRef[HashRef],
  default => sub { [] },
);

has xp_reward => (
  is  => 'ro',
  isa => Maybe[Int],
);

has coin_reward => (
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

  my $maps = $data->{maps} // ($data->{map} ? [$data->{map}] : []);

  return $class->new(
    id           => $data->{id},
    name         => $data->{name},
    type         => $data->{type},
    description  => $data->{description},
    maps         => $maps,
    duration     => $data->{duration},
    cooldown     => $data->{cooldown} // $data->{frequency},
    loot         => $data->{loot} // [],
    xp_reward    => $data->{xpReward},
    coin_reward  => $data->{coinReward},
    last_updated => $data->{lastUpdated},
    _raw         => $data,
  );
}

1;

=head1 SYNOPSIS

  my $arcs = $api->arcs(includeLoot => 'true');
  for my $arc (@$arcs) {
      say $arc->name . " on " . join(", ", $arc->maps->@*);
  }

=head1 DESCRIPTION

Represents an ARC (mission/event) from the ARC Raiders game.

=attr id

Arc identifier.

=attr name

Arc name.

=attr type

Arc type (e.g., "MajorEvent", "MinorEvent").

=attr description

Arc description text.

=attr maps

ArrayRef of map names where this arc occurs.

=attr duration

Duration in seconds.

=attr cooldown

Cooldown between occurrences in seconds.

=attr loot

ArrayRef of loot drops: C<[{ item => "Name", chance => 0.15 }]>.

=attr xp_reward

Experience points reward.

=attr coin_reward

Coin reward.

=attr last_updated

ISO timestamp of last data update.

=method from_hashref

  my $arc = WWW::MetaForge::ArcRaiders::Result::Arc->from_hashref(\%data);

Construct from API response. Handles both C<map> and C<maps> fields.

=cut
