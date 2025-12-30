package WWW::MetaForge::GameMapData::Result::MapMarker;
# ABSTRACT: Base map marker result object for MetaForge Game Map Data API

use Moo;
use Types::Standard qw(Str Num Int HashRef Maybe);
use namespace::clean;

# Generic fields common to all game map data

has id => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has lat => (
  is       => 'ro',
  isa      => Num,
  required => 1,
);

has lng => (
  is       => 'ro',
  isa      => Num,
  required => 1,
);

has zlayers => (
  is  => 'ro',
  isa => Maybe[Int],
);

has mapID => (
  is  => 'ro',
  isa => Maybe[Str],
);

has updated_at => (
  is  => 'ro',
  isa => Maybe[Str],
);

has added_by => (
  is  => 'ro',
  isa => Maybe[Str],
);

has last_edited_by => (
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
    id             => $data->{id},
    lat            => $data->{lat},
    lng            => $data->{lng},
    zlayers        => $data->{zlayers},
    mapID          => $data->{mapID},
    updated_at     => $data->{updated_at},
    added_by       => $data->{added_by},
    last_edited_by => $data->{last_edited_by},
    _raw           => $data,
  );
}

# Convenience accessors

sub x { shift->lng }
sub y { shift->lat }
sub z { shift->zlayers }

# Subclasses should override to provide marker type
sub type { undef }
sub name { undef }

sub coordinates {
  my ($self) = @_;
  return {
    x => $self->lng,
    y => $self->lat,
    defined $self->zlayers ? (z => $self->zlayers) : (),
  };
}

1;

=head1 SYNOPSIS

  my $markers = $api->map_data(map => 'dam');
  for my $marker (@$markers) {
      say "Marker at " . $marker->lng . ", " . $marker->lat;
  }

=head1 DESCRIPTION

Base class for map marker objects from the MetaForge Game Map Data API.
Contains only generic fields common to all games.

Game-specific distributions should subclass this to add game-specific
attributes (like category, subcategory for ARC Raiders).

=attr id

Unique marker identifier (UUID).

=attr lat

Latitude (Y coordinate) on the map.

=attr lng

Longitude (X coordinate) on the map.

=attr zlayers

Z-layer value for elevation/floor.

=attr mapID

Map identifier (e.g., "dam", "spaceport").

=attr updated_at

ISO timestamp of last update.

=attr added_by

Username who added this marker.

=attr last_edited_by

Username who last edited this marker.

=method from_hashref

  my $marker = WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref(\%data);

Construct from API response hash. Subclasses should override this to
handle game-specific fields.

=method x

Alias for C<lng>.

=method y

Alias for C<lat>.

=method z

Alias for C<zlayers>.

=method coordinates

  my $coords = $marker->coordinates;
  # { x => 123.5, y => 78.1 }

Returns HashRef of coordinates.

=cut
