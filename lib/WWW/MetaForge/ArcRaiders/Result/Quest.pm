package WWW::MetaForge::ArcRaiders::Result::Quest;
# ABSTRACT: Quest result object
our $VERSION = '0.003';
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

has objectives => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has xp => (
  is  => 'ro',
  isa => Maybe[Int],
);

has granted_items => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has created_at => (
  is  => 'ro',
  isa => Maybe[Str],
);

has updated_at => (
  is  => 'ro',
  isa => Maybe[Str],
);

has locations => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has marker_category => (
  is  => 'ro',
  isa => Maybe[Str],
);

has image => (
  is  => 'ro',
  isa => Maybe[Str],
);

has guide_links => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has trader_name => (
  is  => 'ro',
  isa => Maybe[Str],
);

has sort_order => (
  is  => 'ro',
  isa => Maybe[Int],
);

has position => (
  is  => 'ro',
  isa => Maybe[HashRef],
);

has required_items => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has rewards => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has _raw => (
  is  => 'ro',
  isa => HashRef,
);

sub from_hashref {
  my ($class, $data) = @_;
  return $class->new(
    id             => $data->{id},
    name           => $data->{name},
    objectives     => $data->{objectives} // [],
    xp             => $data->{xp},
    granted_items  => $data->{grantedItems} // [],
    created_at     => $data->{createdAt},
    updated_at     => $data->{updatedAt},
    locations      => $data->{locations} // [],
    marker_category => $data->{markerCategory},
    image          => $data->{image},
    guide_links    => $data->{guideLinks} // [],
    trader_name    => $data->{traderName},
    sort_order     => $data->{sortOrder},
    position       => $data->{position},
    required_items => $data->{requiredItems} // [],
    rewards        => $data->{rewards} // [],
    _raw           => $data,
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

=attr objectives

ArrayRef of objective strings.

=attr xp

Experience points reward.

=attr granted_items

ArrayRef of items granted on quest completion.

=attr created_at

ISO timestamp of creation.

=attr updated_at

ISO timestamp of last update.

=attr locations

ArrayRef of location strings.

=attr marker_category

Marker category for map display.

=attr image

Quest image URL.

=attr guide_links

ArrayRef of guide link URLs.

=attr trader_name

Name of the trader associated with this quest.

=attr sort_order

Sort order for quest listing.

=attr position

HashRef with x/y coordinates for map position.

=attr required_items

ArrayRef of required items: C<[{ item => "Name", quantity => 5 }]>.

=attr rewards

ArrayRef of rewards with nested item structure:
C<[{ item => { id, icon, name, rarity, item_type }, quantity => "5" }]>.
Note: quantity is a string.

=method from_hashref

  my $quest = WWW::MetaForge::ArcRaiders::Result::Quest->from_hashref(\%data);

Construct from API response.

=cut