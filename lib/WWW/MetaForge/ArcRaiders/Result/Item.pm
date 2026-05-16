package WWW::MetaForge::ArcRaiders::Result::Item;
# ABSTRACT: Item result object
our $VERSION = '0.003';
use Moo;
use Types::Standard qw(Str Int Num ArrayRef HashRef Maybe);
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

has item_type => (
  is  => 'ro',
  isa => Maybe[Str],
);

has loadout_slots => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has icon => (
  is  => 'ro',
  isa => Maybe[Str],
);

has rarity => (
  is  => 'ro',
  isa => Maybe[Str],
);

has value => (
  is  => 'ro',
  isa => Maybe[Int],
);

has workbench => (
  is  => 'ro',
  isa => Maybe[Str],
);

has stat_block => (
  is  => 'ro',
  isa => Maybe[HashRef],
);

has weight => (
  is  => 'ro',
  isa => Maybe[Num],
);

has stack_size => (
  is  => 'ro',
  isa => Maybe[Int],
);

has _raw => (
  is  => 'ro',
  isa => HashRef,
);

sub from_hashref {
  my ($class, $data) = @_;

  my $stat_block = $data->{stat_block};
  my $weight     = $stat_block && exists $stat_block->{weight} ? $stat_block->{weight} : undef;
  my $stack_size = $stat_block && exists $stat_block->{stackSize} ? $stat_block->{stackSize} : undef;

  return $class->new(
    id            => $data->{id},
    name          => $data->{name},
    description   => $data->{description},
    item_type     => $data->{item_type},
    loadout_slots => $data->{loadout_slots} // [],
    icon          => $data->{icon},
    rarity        => $data->{rarity},
    value         => $data->{value},
    workbench     => $data->{workbench},
    stat_block    => $stat_block,
    weight        => $weight,
    stack_size    => $stack_size,
    _raw          => $data,
  );
}

1;

=head1 SYNOPSIS

  my $items = $api->items(search => 'Ferro');
  for my $item (@$items) {
      say $item->name . " (" . $item->rarity . ")";
      say "  Weight: " . $item->weight if $item->weight;
  }

=head1 DESCRIPTION

Represents an item from the ARC Raiders game (weapons, mods, materials, consumables).

=attr id

Item identifier (string slug).

=attr name

Human-readable item name.

=attr description

Item description text.

=attr item_type

Item type (e.g., "Weapon", "Material", "Consumable").

=attr loadout_slots

ArrayRef of loadout slot names this item occupies.

=attr icon

Icon identifier or URL.

=attr rarity

Item rarity (e.g., "Common", "Rare", "Legendary").

=attr value

Base monetary value.

=attr workbench

Workbench type required for crafting.

=attr stat_block

HashRef of item statistics (damage, range, weight, stackSize, etc.).

=attr weight

Item weight value (from stat_block).

=attr stack_size

Maximum stack size for stackable items (from stat_block).

=method from_hashref

  my $item = WWW::MetaForge::ArcRaiders::Result::Item->from_hashref(\%data);

Construct from API response.

=cut
