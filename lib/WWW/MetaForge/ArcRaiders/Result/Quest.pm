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

has description => (
  is  => 'ro',
  isa => Maybe[Str],
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

has guide_url => (
  is  => 'ro',
  isa => Maybe[Str],
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

has additional_rewards => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has manifest => (
  is      => 'ro',
  isa     => HashRef,
  default => sub { {} },
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
    description    => $data->{description},
    objectives     => $data->{objectives} // [],
    xp             => $data->{xp},
    granted_items  => $data->{granted_items} // [],
    created_at     => $data->{created_at},
    updated_at     => $data->{updated_at},
    locations      => $data->{locations} // [],
    marker_category => $data->{marker_category},
    image          => $data->{image},
    guide_links    => $data->{guide_links} // [],
    guide_url      => $data->{guide_url},
    trader_name    => $data->{trader_name},
    sort_order     => $data->{sort_order},
    position       => $data->{position},
    required_items => $data->{required_items} // [],
    rewards        => $data->{rewards} // [],
    additional_rewards => $data->{additional_rewards} // [],
    manifest       => $data->{manifest} // {},
    _raw           => $data,
  );
}

1;

=head1 SYNOPSIS

  my $quests = $api->quests(search => 'Celeste');
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

=attr description

Quest description text.

=attr objectives

ArrayRef of objective strings.

=attr xp

Experience points reward.

=attr granted_items

ArrayRef of items the quest grants, in the same shape as C<rewards>.

=attr created_at

ISO timestamp of creation.

=attr updated_at

ISO timestamp of last update.

=attr locations

ArrayRef of location hashes: C<< [{ map, x, y }] >> or C<< [{ map, id }] >>.

=attr marker_category

Marker category for map display.

=attr image

Quest image URL.

=attr guide_links

ArrayRef of guide links. The API sends the key, but on 2026-11-03 it was
empty for every quest.

=attr guide_url

Path to the quest's guide page on metaforge.app, or C<undef> if none exists.

=attr trader_name

Name of the trader associated with this quest.

=attr sort_order

Sort order for quest listing.

=attr position

HashRef with x/y coordinates for map position, or C<undef> when the API
sends C<null>.

=attr required_items

ArrayRef of required items, in the same shape as C<rewards>.

=attr rewards

ArrayRef of item rewards with nested item structure:
C<< [{ id, item => { id, icon, name, rarity, item_type }, item_id, quantity }] >>.
C<id> and C<quantity> are integers.

=attr additional_rewards

ArrayRef of rewards that are not items:
C<< [{ kind, name, quantity }] >>. C<kind> is C<currency> (C<name> e.g.
C<XP>, C<Coins>, C<Raider Tokens>) or C<cosmetic-option>, which also
carries C<group> and C<setting> and, for some, C<included_with>
(e.g. C<< { group => 'Aviator', setting => 'Color', name => 'Dusted Cream' } >>).
C<quantity> is an integer.

=attr manifest

HashRef with the quest's structure:
C<< { cadence, conditions, coverage, objective_graph, objective_root, prerequisites, updated_at } >>.
C<prerequisites> lists the quests to finish first:
C<< [{ quest_id, name, required_state }] >>. C<objective_graph> is a list of
objective nodes C<< { id, kind, description, action => { type, amount }, children, hidden, optional, required_count, round_constraint } >>
starting at the node named by C<objective_root>.

=method from_hashref

  my $quest = WWW::MetaForge::ArcRaiders::Result::Quest->from_hashref(\%data);

Construct from API response.

=cut