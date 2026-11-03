package WWW::MetaForge::ArcRaiders::Result::HideoutStation::Level;
# ABSTRACT: One upgrade level of a hideout station
our $VERSION = '0.003';
use Moo;
use Types::Standard qw(Str Int ArrayRef HashRef);
use namespace::clean;

has number => (
  is       => 'ro',
  isa      => Int,
  required => 1,
);

has required_items => (
  is      => 'ro',
  isa     => ArrayRef[HashRef],
  default => sub { [] },
);

has unlock_requirements => (
  is      => 'ro',
  isa     => ArrayRef[HashRef],
  default => sub { [] },
);

has crafts => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  default => sub { [] },
);

has _raw => (
  is       => 'ro',
  isa      => HashRef,
  required => 1,
);

sub from_hashref {
  my ($class, $data, $number) = @_;
  return $class->new(
    number              => $number,
    required_items      => $data->{requiredItems} // [],
    unlock_requirements => $data->{unlockRequirements} // [],
    crafts              => $data->{crafts} // [],
    _raw                => $data,
  );
}

1;

=head1 SYNOPSIS

  my ($gunsmith) = grep { $_->id eq 'weapon-bench' } @{ $api->hideout };
  my $level = $gunsmith->level(2);
  for my $req ($level->required_items->@*) {
      printf "%dx %s\n", $req->{quantity}, $req->{id};
  }

=head1 DESCRIPTION

One entry of the C<levels> object of a hideout station in the ARC Raiders
C</hideout> response. The API keys the levels by their number
(C<< levels => { "1" => {...}, "2" => {...} } >>); the number becomes
L</number>, the level object itself is kept in C<_raw>. Every key of a level
is optional: the first level of Scrappy and of the Outpost is C<{}>.

=attr number

The level number, taken from the key of the C<levels> object.

=attr required_items

ArrayRef of the items an upgrade to this level takes:
C<< [{ id, quantity }] >>, with C<id> an item id (e.g. C<metal-parts>) and
C<quantity> an integer. Empty when the API sends none.

=attr unlock_requirements

ArrayRef of what has to happen before this level can be built:
C<< [{ id, quantity }] >>, with C<id> e.g. C<rounds-played> or C<raids>.
The API sends it only for the first level of the crafting stations.

=attr crafts

ArrayRef of the item ids this level adds to the station's crafting list.

=attr _raw

The untouched level object from the API response.

=method from_hashref

  my $level = WWW::MetaForge::ArcRaiders::Result::HideoutStation::Level->from_hashref(\%data, $number);

Construct from one value of the C<levels> object, with its key as the level
number.

=cut
