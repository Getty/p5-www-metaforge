package WWW::MetaForge::ArcRaiders::Result::Trader;
# ABSTRACT: Trader result object
our $VERSION = '0.002';
use Moo;
use Types::Standard qw(Str Int ArrayRef HashRef Maybe);
use namespace::clean;

has name => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has description => (
  is  => 'ro',
  isa => Maybe[Str],
);

has location => (
  is  => 'ro',
  isa => Maybe[Str],
);

has inventory => (
  is      => 'ro',
  isa     => ArrayRef[HashRef],
  default => sub { [] },
);

has last_refresh => (
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
    name         => $data->{name},
    description  => $data->{description},
    location     => $data->{location},
    inventory    => $data->{inventory} // [],
    last_refresh => $data->{lastRefresh},
    _raw         => $data,
  );
}

sub find_item {
  my ($self, $item_name) = @_;
  for my $item ($self->inventory->@*) {
    return $item if lc($item->{item} // '') eq lc($item_name);
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
          say "  Sells Ferro I for $item->{price}";
      }
  }

=head1 DESCRIPTION

Represents a trader NPC from the ARC Raiders game.

=attr name

Trader name (e.g., "Apollo", "TianWen").

=attr description

Trader description text.

=attr location

Where the trader can be found.

=attr inventory

ArrayRef of items for sale: C<[{ item => "Name", price => 1000, stock => 5 }]>.

=attr last_refresh

ISO timestamp of last inventory refresh.

=method from_hashref

  my $trader = WWW::MetaForge::ArcRaiders::Result::Trader->from_hashref(\%data);

Construct from API response.

=method find_item

  my $info = $trader->find_item('Ferro I');

Search inventory by name (case-insensitive). Returns inventory entry or undef.

=method has_item

  if ($trader->has_item('Metal Parts')) { ... }

Returns true if trader sells the named item.

=cut
