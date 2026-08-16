package WWW::MetaForge::ArcRaiders::Result::Trader;
# ABSTRACT: Trader result object
our $VERSION = '0.003';
use Moo;
use Types::Standard qw(Str ArrayRef HashRef);
use namespace::clean;

has name => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has inventory => (
  is      => 'ro',
  isa     => ArrayRef[HashRef],
  default => sub { [] },
);

has _raw => (
  is  => 'ro',
  isa => HashRef,
);

sub from_hashref {
  my ($class, $data) = @_;
  return $class->new(
    name      => $data->{name},
    inventory => $data->{inventory} // [],
    _raw      => $data,
  );
}

sub find_item {
  my ($self, $item_name) = @_;
  for my $item ($self->inventory->@*) {
    return $item if lc($item->{name} // '') eq lc($item_name);
  }
  return undef;
}

sub has_item {
  my ($self, $item_name) = @_;
  return defined $self->find_item($item_name);
}

1;

=head1 SYNOPSIS

  my $traders = $api->traders;
  for my $trader (@$traders) {
      say $trader->name;
      if (my $item = $trader->find_item('Ferro I')) {
          say "  Sells $item->{name} for $item->{trader_price}";
      }
  }

=head1 DESCRIPTION

Represents a trader NPC from the ARC Raiders game.

=attr name

Trader name (e.g., "Apollo", "TianWen").

=attr inventory

ArrayRef of items for sale. Each item hash contains:
- id: item identifier
- icon: CDN URL for item icon
- name: item display name
- value: base value
- rarity: item rarity (e.g., "Uncommon", "Rare")
- item_type: type category (e.g., "Quick Use", "Weapon")
- description: item description
- trader_price: price from this trader

=attr _raw

Raw HashRef of the original API data for this trader.

=method from_hashref

  my $trader = WWW::MetaForge::ArcRaiders::Result::Trader->from_hashref(\%data);

Construct from API response.

=method find_item

  my $item = $trader->find_item('Ferro I');

Search inventory by name (case-insensitive). Returns inventory entry or undef.

=method has_item

  if ($trader->has_item('Metal Parts')) { ... }

Returns true if trader sells the named item.

=cut
