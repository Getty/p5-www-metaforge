package WWW::MetaForge::ArcRaiders::Result::MapMarker;
# ABSTRACT: Map marker/POI result object for ARC Raiders

use Moo;
use Types::Standard qw(Str Int Bool Maybe ArrayRef Any);
use namespace::clean;

extends 'WWW::MetaForge::GameMapData::Result::MapMarker';

# ARC Raiders specific attributes

has map_id => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has category => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has subcategory => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has behind_locked_door => (
  is  => 'ro',
  isa => Bool,
  default => 0,
);

has event_condition_mask => (
  is  => 'ro',
  isa => Maybe[Int],
);

has loot_areas => (
  is  => 'ro',
  isa => Maybe[Any],  # Can be ArrayRef or String
);

has related_item => (
  is  => 'ro',
  isa => Maybe[Str],
);

has related_quest => (
  is  => 'ro',
  isa => Maybe[Str],
);

sub from_hashref {
  my ($class, $data) = @_;

  # Extract coordinates from various formats (same as base class)
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
    $x = $data->{x} // $data->{lng};
    $y = $data->{y} // $data->{lat};
    $z = $data->{z} // $data->{zlayers};
  }

  # Build type from category/subcategory
  my $type = $data->{type} // $data->{category};
  if ($data->{subcategory} && !$data->{type}) {
    $type = $data->{category} . '/' . $data->{subcategory} if $data->{category};
  }

  return $class->new(
    # Base class fields
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
    # ARC Raiders specific
    map_id              => $data->{mapID},
    category            => $data->{category},
    subcategory         => $data->{subcategory},
    behind_locked_door  => $data->{behindLockedDoor} ? 1 : 0,
    event_condition_mask => $data->{eventConditionMask},
    loot_areas          => $data->{lootAreas},
    related_item        => $data->{relatedItem} // $data->{related_item},
    related_quest       => $data->{relatedQuest} // $data->{related_quest},
  );
}

1;

=head1 SYNOPSIS

  my $markers = $api->map_data(map => 'dam');
  for my $marker (@$markers) {
      say $marker->category . '/' . $marker->subcategory;
      say "  (" . $marker->x . ", " . $marker->y . ")";
      say "  Behind locked door" if $marker->behind_locked_door;
  }

=head1 DESCRIPTION

Represents a map marker or POI from the ARC Raiders game maps.

Extends L<WWW::MetaForge::GameMapData::Result::MapMarker> with
ARC Raiders specific attributes.

=head1 INHERITED ATTRIBUTES

From L<WWW::MetaForge::GameMapData::Result::MapMarker>:

=over 4

=item * id - Marker identifier (UUID)

=item * type - Combined category/subcategory (e.g., "arc/tick")

=item * name - Marker name (instanceName)

=item * x, y - Coordinates (from lng, lat)

=item * z - Z-layer

=item * last_updated - ISO timestamp

=back

=attr map_id

Map identifier (e.g., "dam", "spaceport", "blue-gate").

=attr category

Primary marker category (e.g., "arc", "containers", "loot").

=attr subcategory

Secondary category (e.g., "tick", "pop", "base_container").

=attr behind_locked_door

Boolean - true if marker is behind a locked door.

=attr event_condition_mask

Bitmask for event conditions when this marker appears.

=attr loot_areas

ArrayRef of loot area data (if applicable).

=attr related_item

Associated item (e.g., resource type that spawns here).

=attr related_quest

Associated quest name (for quest objectives).

=cut
