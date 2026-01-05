package WWW::MetaForge::ArcRaiders::Result::Item;
# ABSTRACT: Item result object
our $VERSION = '0.002';
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

has slug => (
  is  => 'ro',
  isa => Maybe[Str],
);

has category => (
  is  => 'ro',
  isa => Maybe[Str],
);

has rarity => (
  is  => 'ro',
  isa => Maybe[Str],
);

has description => (
  is  => 'ro',
  isa => Maybe[Str],
);

has stats => (
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

has base_value => (
  is  => 'ro',
  isa => Maybe[Int],
);

has crafting_requirements => (
  is      => 'ro',
  isa     => ArrayRef[HashRef],
  default => sub { [] },
);

has sold_by => (
  is      => 'ro',
  isa     => ArrayRef[HashRef],
  default => sub { [] },
);

has used_in => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has compatible_with => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has recycle_yield => (
  is  => 'ro',
  isa => Maybe[HashRef],
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

  # Handle both documented and actual API field names
  my $stats = $data->{stats} // $data->{stat_block};
  my $weight = $data->{weight} // ($stats ? $stats->{weight} : undef);
  my $stack_size = $data->{stackSize} // ($stats ? $stats->{stackSize} : undef);

  return $class->new(
    id                    => $data->{id},
    name                  => $data->{name},
    slug                  => $data->{slug} // $data->{id},
    category              => $data->{category} // $data->{item_type},
    rarity                => $data->{rarity},
    description           => $data->{description},
    stats                 => $stats,
    weight                => $weight,
    stack_size            => $stack_size,
    base_value            => $data->{baseValue} // $data->{value},
    crafting_requirements => $data->{components} // [],
    sold_by               => $data->{soldBy} // [],
    used_in               => $data->{usedIn} // [],
    compatible_with       => $data->{compatibleWith} // [],
    recycle_yield         => $data->{recycleYield},
    last_updated          => $data->{lastUpdated} // $data->{updated_at},
    _raw                  => $data,
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

=attr slug

URL-safe identifier.

=attr category

Item type (e.g., "Weapon", "Material", "Consumable").

=attr rarity

Item rarity (e.g., "Common", "Rare", "Legendary").

=attr description

Item description text.

=attr stats

HashRef of item statistics (damage, range, etc.).

=attr weight

Item weight value.

=attr stack_size

Maximum stack size for stackable items.

=attr base_value

Base monetary value.

=attr crafting_requirements

ArrayRef of crafting ingredients: C<[{ item => "Name", quantity => 5 }]>.

=attr sold_by

ArrayRef of traders that sell this item.

=attr used_in

ArrayRef of recipes/crafts using this item.

=attr compatible_with

ArrayRef of compatible items.

=attr recycle_yield

HashRef of materials from recycling.

=attr last_updated

ISO timestamp of last data update.

=method from_hashref

  my $item = WWW::MetaForge::ArcRaiders::Result::Item->from_hashref(\%data);

Construct from API response. Handles field name mapping.

=cut
