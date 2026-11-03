package WWW::MetaForge::ArcRaiders::Result::HideoutStation;
# ABSTRACT: Hideout station result object
our $VERSION = '0.003';
use Moo;
use Types::Standard qw(Str Int ArrayRef HashRef InstanceOf);
use WWW::MetaForge::ArcRaiders::Result::HideoutStation::Level;
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

has max_level => (
  is  => 'ro',
  isa => Int,
);

has levels => (
  is      => 'ro',
  isa     => ArrayRef[InstanceOf['WWW::MetaForge::ArcRaiders::Result::HideoutStation::Level']],
  default => sub { [] },
);

has _raw => (
  is       => 'ro',
  isa      => HashRef,
  required => 1,
);

sub from_hashref {
  my ($class, $data) = @_;

  my $levels = $data->{levels} // {};
  my @levels = map {
    WWW::MetaForge::ArcRaiders::Result::HideoutStation::Level->from_hashref($levels->{$_}, $_)
  } sort { $a <=> $b } keys %$levels;

  return $class->new(
    id        => $data->{id},
    name      => $data->{name},
    max_level => $data->{maxLevel},
    levels    => \@levels,
    _raw      => $data,
  );
}

sub level {
  my ($self, $number) = @_;
  my ($level) = grep { $_->number == $number } $self->levels->@*;
  return $level;
}

1;

=head1 SYNOPSIS

  my $stations = $api->hideout;
  for my $station (@$stations) {
      printf "%s (%d levels)\n", $station->name, $station->max_level;
  }

  # What does level 3 of the Gunsmith take?
  my ($gunsmith) = grep { $_->id eq 'weapon-bench' } @$stations;
  for my $req ($gunsmith->level(3)->required_items->@*) {
      printf "%dx %s\n", $req->{quantity}, $req->{id};
  }

=head1 DESCRIPTION

Represents one station of the ARC Raiders hideout from the C</hideout>
response: a crafting bench (e.g. Gunsmith, Gear Bench, Refiner), Scrappy or
the Outpost, with the items each upgrade level takes.

=attr id

Station identifier (string slug, e.g. C<weapon-bench>, C<scrappy>).

=attr name

Station name (e.g. "Gunsmith", "Medical Lab").

=attr max_level

Highest level of the station.

=attr levels

ArrayRef of L<WWW::MetaForge::ArcRaiders::Result::HideoutStation::Level>,
one per entry of the API's C<levels> object, sorted by level number.

=attr _raw

Raw HashRef of the original API data for this station.

=method from_hashref

  my $station = WWW::MetaForge::ArcRaiders::Result::HideoutStation->from_hashref(\%data);

Construct from API response.

=method level

  my $level = $station->level(2);

Returns the L<WWW::MetaForge::ArcRaiders::Result::HideoutStation::Level>
with that number, or undef if the station has no such level.

=cut
