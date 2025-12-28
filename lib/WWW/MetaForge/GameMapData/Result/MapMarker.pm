package WWW::MetaForge::GameMapData::Result::MapMarker;
# ABSTRACT: Base class for map marker result objects

use Moo;
use Types::Standard qw(Str Num HashRef Maybe);
use namespace::clean;

has id => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has type => (
  is  => 'ro',
  isa => Maybe[Str],
);

has name => (
  is  => 'ro',
  isa => Maybe[Str],
);

has description => (
  is  => 'ro',
  isa => Maybe[Str],
);

has x => (
  is       => 'ro',
  isa      => Num,
  required => 1,
);

has y => (
  is       => 'ro',
  isa      => Num,
  required => 1,
);

has z => (
  is  => 'ro',
  isa => Maybe[Num],
);

has icon => (
  is  => 'ro',
  isa => Maybe[Str],
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

  # Extract coordinates from various formats
  my ($x, $y, $z);
  if (exists $data->{coordinates} && ref $data->{coordinates} eq 'HASH') {
    $x = $data->{coordinates}{x};
    $y = $data->{coordinates}{y};
    $z = $data->{coordinates}{z};
  } elsif (exists $data->{position} && ref $data->{position} eq 'HASH') {
    $x = $data->{position}{x};
    $y = $data->{position}{y};
    $z = $data->{position}{z};
  } else {
    # Support both x/y and lat/lng formats
    $x = $data->{x} // $data->{lng};
    $y = $data->{y} // $data->{lat};
    $z = $data->{z} // $data->{zlayers};
  }

  # Build type from category/subcategory if present
  my $type = $data->{type} // $data->{category};
  if ($data->{subcategory} && !$data->{type}) {
    $type = $data->{category} . '/' . $data->{subcategory} if $data->{category};
  }

  return $class->new(
    id           => $data->{id},
    type         => $type,
    name         => $data->{name} // $data->{title} // $data->{instanceName},
    description  => $data->{description},
    x            => $x,
    y            => $y,
    z            => $z,
    icon         => $data->{icon} // $data->{image},
    last_updated => $data->{lastUpdated} // $data->{updated_at},
    _raw         => $data,
  );
}

sub coordinates {
  my ($self) = @_;
  return {
    x => $self->x,
    y => $self->y,
    defined $self->z ? (z => $self->z) : (),
  };
}

1;

=head1 SYNOPSIS

  my $markers = $api->map_data(map => 'Dam');
  for my $marker (@$markers) {
      say $marker->name;
      say "  Type: " . $marker->type;
      say "  Position: " . $marker->x . ", " . $marker->y;
  }

=head1 DESCRIPTION

Base class for map marker objects from the MetaForge Game Map Data API.
Contains generic attributes common to all game map markers.

Game-specific distributions should subclass this to add game-specific
attributes.

=attr id

Unique marker identifier.

=attr type

Marker type/category (e.g., "loot", "quest", "poi").

=attr name

Human-readable marker name.

=attr description

Optional description or tooltip text.

=attr x

X coordinate on the map.

=attr y

Y coordinate on the map.

=attr z

Optional Z coordinate (elevation/floor).

=attr icon

URL or identifier for the marker icon.

=attr last_updated

ISO timestamp of last data update.

=method from_hashref

  my $marker = WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref(\%data);

Construct from API response. Handles various coordinate formats
(C<coordinates.x>, C<position.x>, or direct C<x> fields).

=method coordinates

  my $coords = $marker->coordinates;
  # { x => 123.5, y => 78.1 }

Returns HashRef of coordinates.

=cut
