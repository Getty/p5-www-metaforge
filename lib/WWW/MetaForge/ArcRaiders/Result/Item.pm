package WWW::MetaForge::ArcRaiders::Result::Item;
# ABSTRACT: Item result object
our $VERSION = '0.003';
use Moo;
use Types::Standard qw(Str Int Num Bool ArrayRef HashRef Maybe);
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

has flavor_text => (
  is  => 'ro',
  isa => Maybe[Str],
);

has subcategory => (
  is  => 'ro',
  isa => Maybe[Str],
);

has shield_type => (
  is  => 'ro',
  isa => Maybe[Str],
);

has loot_area => (
  is  => 'ro',
  isa => Maybe[Str],
);

has ammo_type => (
  is  => 'ro',
  isa => Maybe[Str],
);

has article => (
  is  => 'ro',
  isa => Maybe[Str],
);

has guide_url => (
  is  => 'ro',
  isa => Maybe[Str],
);

has guide_links => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has locations => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has cosmetic => (
  is      => 'ro',
  isa     => HashRef,
  default => sub { {} },
);

has unlocks_weapon => (
  is      => 'ro',
  isa     => Bool,
  coerce  => sub { $_[0] ? 1 : 0 },
  default => 0,
);

has components => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has recycle_components => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has sold_by => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has used_in => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has recycle_from => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has mods => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has dropped_by => (
  is      => 'ro',
  isa     => ArrayRef,
  default => sub { [] },
);

has relationships => (
  is      => 'ro',
  isa     => HashRef,
  default => sub { {} },
);

has updated_at => (
  is  => 'ro',
  isa => Maybe[Str],
);

has created_at => (
  is  => 'ro',
  isa => Maybe[Str],
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
    id                 => $data->{id},
    name               => $data->{name},
    description        => $data->{description},
    item_type          => $data->{item_type},
    loadout_slots      => $data->{loadout_slots} // [],
    icon               => $data->{icon},
    rarity             => $data->{rarity},
    value              => $data->{value},
    workbench          => $data->{workbench},
    stat_block         => $stat_block,
    weight             => $weight,
    stack_size         => $stack_size,
    flavor_text        => $data->{flavor_text},
    subcategory        => $data->{subcategory},
    shield_type        => $data->{shield_type},
    loot_area          => $data->{loot_area},
    ammo_type          => $data->{ammo_type},
    article            => $data->{article},
    guide_url          => $data->{guide_url},
    guide_links        => $data->{guide_links} // [],
    locations          => $data->{locations} // [],
    cosmetic           => $data->{cosmetic} // {},
    unlocks_weapon     => $data->{unlocks_weapon} // 0,
    components         => $data->{components} // [],
    recycle_components => $data->{recycle_components} // [],
    sold_by            => $data->{sold_by} // [],
    used_in            => $data->{used_in} // [],
    recycle_from       => $data->{recycle_from} // [],
    mods               => $data->{mods} // [],
    dropped_by         => $data->{dropped_by} // [],
    relationships      => $data->{relationships} // {},
    updated_at         => $data->{updated_at},
    created_at         => $data->{created_at},
    _raw               => $data,
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

Item type (e.g., "Weapon", "Quick Use", "Topside Material"). The C<items>
endpoint filters on it server-side with the exact, case-sensitive value:
C<< $api->items(item_type => 'Quick Use') >>.

=attr loadout_slots

ArrayRef of loadout slot names this item can go into (e.g., C<backpack>,
C<safePocket>, C<quickUse>, C<weapon>, C<shield>).

=attr icon

URL of the item icon.

=attr rarity

Item rarity (e.g., "Common", "Rare", "Legendary", "Amplified"). The C<items>
endpoint filters on it server-side with the exact, case-sensitive value:
C<< $api->items(rarity => 'Legendary') >>.

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

=attr flavor_text

Short in-game flavor text.

=attr subcategory

Item subcategory (e.g., "Assault Rifle", "Backpack Charm", "Seating").

=attr shield_type

Shield class of a shield item (C<light>, C<medium>, C<heavy>).

=attr loot_area

Loot area(s) the item is found in, comma-separated (e.g., "ARC",
"Commercial, Residential").

=attr ammo_type

Ammunition type a weapon uses (e.g., C<light>, C<medium>, C<energy>).

=attr article

Long-form MetaForge article about the item, as HTML.

=attr guide_url

URL of a MetaForge guide for the item.

=attr guide_links

ArrayRef of guide links, each C<< { label => $str, url => $str } >>.

=attr locations

ArrayRef of map locations of the item, each C<< { id => $uuid, map => $map_id } >>.
C<map> is a map ID as returned by L<WWW::MetaForge::ArcRaiders/maps>.

=attr cosmetic

HashRef describing a cosmetic item: C<kind> (e.g., "Outfit", "Emote"),
C<slot>, C<settings> (each C<< { name => $str, options => [ { name => $str } ] } >>),
and for variants C<parentItemId>, C<parentName> and C<optionName>. Empty
HashRef for non-cosmetic items (the API sends C<null>).

=attr unlocks_weapon

Boolean, true for blueprints and recipes that unlock a weapon. The API only
sends the field when it is true.

=attr components

ArrayRef of crafting components, each C<< { quantity => $n, component => \%item } >>
where C<%item> holds C<id>, C<name>, C<icon>, C<item_type> and C<rarity>.
Only sent with C<includeComponents =E<gt> 'true'>.

=attr recycle_components

ArrayRef of recycling yield components, same shape as C<components> (the
component additionally carries C<description> and C<value>). Only sent with
C<includeComponents =E<gt> 'true'>.

=attr sold_by

ArrayRef of traders selling this item, each C<< { price => $n, trader_name => $str } >>.
Only sent with C<includeComponents =E<gt> 'true'>.

=attr used_in

ArrayRef of the items this item is a component of, each
C<< { quantity => $n, item => \%item } >>; crafting recipes also carry
C<output_quantity>. Only sent with C<includeComponents =E<gt> 'true'>.

=attr recycle_from

ArrayRef of the items that yield this item when recycled, each
C<< { quantity => $n, item => \%item } >>; C<quantity> is how many of this
item one recycle yields. Only sent with C<includeComponents =E<gt> 'true'>.

=attr mods

ArrayRef of compatible items, each C<< { mod => \%item } >>: the mods that fit
a weapon, or the weapons a mod fits. Only sent with
C<includeComponents =E<gt> 'true'>.

=attr dropped_by

ArrayRef of the ARCs that drop this item, each
C<< { id => $uuid, arc_id => $str, created_at => $ts, arc => \%arc } >>
where C<%arc> holds C<id>, C<name>, C<icon> and C<description>. Only sent
with C<includeComponents =E<gt> 'true'>.

=attr relationships

HashRef of the item's relations as MetaForge links them: C<recipes> (crafting
station, ingredients, blueprints), C<operations> (salvage, repair, upgrade,
round production, field crafting), C<recycling>, C<mods> and
C<blueprintUnlocks> (each present only when it applies), plus C<updatedAt>.
Only sent with C<includeComponents =E<gt> 'true'>; empty HashRef otherwise.

=attr updated_at

Timestamp of the last update to this item record.

=attr created_at

Timestamp of the creation of this item record.

=method from_hashref

  my $item = WWW::MetaForge::ArcRaiders::Result::Item->from_hashref(\%data);

Construct from API response.

=cut
