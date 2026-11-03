package WWW::MetaForge::ArcRaiders::Result::Ermal;
# ABSTRACT: Ermal's offers and permanent services from the traders response
our $VERSION = '0.003';
use Moo;
use Types::Standard qw(Str ArrayRef HashRef Maybe);
use namespace::clean;

has offers => (
  is      => 'ro',
  isa     => ArrayRef[HashRef],
  default => sub { [] },
);

has permanent_services => (
  is      => 'ro',
  isa     => ArrayRef[HashRef],
  default => sub { [] },
);

has synced_at => (
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
    offers             => $data->{offers} // [],
    permanent_services => $data->{permanent_services} // [],
    synced_at          => $data->{synced_at},
    _raw               => $data,
  );
}

1;

=head1 SYNOPSIS

  my $ermal = $api->ermal;
  for my $offer ($ermal->offers->@*) {
      printf "%s: %d coins\n", $offer->{offer_title}, $offer->{coin_cost};
  }
  for my $service ($ermal->permanent_services->@*) {
      say $service->{name};
  }

=head1 DESCRIPTION

Represents the C<ermal> section of the ARC Raiders C</traders> response.
Unlike the other traders, which the API lists with an item inventory under
C<data>, Ermal has a set of time-limited offers and a set of permanent
services. Get it with L<WWW::MetaForge::ArcRaiders/ermal>.

=attr offers

ArrayRef of offers:
C<< [{ id, offer_title, offer_start, offer_end, coin_cost, item, accepted_items }] >>.
C<offer_start> and C<offer_end> are ISO timestamps, C<coin_cost> is an
integer. C<item> is what the offer hands out,
C<< { id, name, icon, item_type, rarity, value, description } >>, or
C<undef> for an offer without an item (e.g. "Raider Tokens x25").
C<accepted_items> lists the items the offer takes:
C<< [{ id, name, icon, item_type, rarity, value, amount }] >>; an entry for
a whole item category (e.g. "Any Firearm") carries C<< is_category => true >>
instead of C<amount>. C<icon>, C<item_type>, C<rarity> and C<value> can be
C<undef>.

=attr permanent_services

ArrayRef of permanent services (e.g. "Expedition Vault", "Stash Expansion"):
C<< [{ id, name, description, coin_cost, accepted_items }] >>, with
C<accepted_items> as C<< [{ id, name, icon, item_type, rarity, value }] >>.

=attr synced_at

ISO timestamp of the last sync of Ermal's data.

=attr _raw

The untouched C<ermal> HashRef from the API response.

=method from_hashref

  my $ermal = WWW::MetaForge::ArcRaiders::Result::Ermal->from_hashref(\%data);

Construct from the C<ermal> section of the API response.

=cut
