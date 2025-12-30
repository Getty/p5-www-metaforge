package WWW::MetaForge::ArcRaiders::Result::MapMarker;
# ABSTRACT: Map marker result object for ARC Raiders

use Moo;
use Types::Standard qw(Str Bool Maybe Int);
use namespace::clean;

extends 'WWW::MetaForge::GameMapData::Result::MapMarker';

# ARC Raiders specific fields

has category => (
  is  => 'ro',
  isa => Maybe[Str],
);

has subcategory => (
  is  => 'ro',
  isa => Maybe[Str],
);

has instanceName => (
  is  => 'ro',
  isa => Maybe[Str],
);

has behindLockedDoor => (
  is     => 'ro',
  isa    => Bool,
  coerce => sub { $_[0] ? 1 : 0 },
);

has eventConditionMask => (
  is  => 'ro',
  isa => Maybe[Int],
);

has lootAreas => (
  is => 'ro',
  # Can be null, string, or array depending on marker type
);

sub from_hashref {
  my ($class, $data) = @_;

  return $class->new(
    # Base class fields
    id             => $data->{id},
    lat            => $data->{lat},
    lng            => $data->{lng},
    zlayers        => $data->{zlayers},
    mapID          => $data->{mapID},
    updated_at     => $data->{updated_at},
    added_by       => $data->{added_by},
    last_edited_by => $data->{last_edited_by},
    _raw           => $data,
    # ARC Raiders specific
    category           => $data->{category},
    subcategory        => $data->{subcategory},
    instanceName       => $data->{instanceName},
    behindLockedDoor   => $data->{behindLockedDoor} // 0,
    eventConditionMask => $data->{eventConditionMask},
    lootAreas          => $data->{lootAreas},
  );
}

# Convenience accessors

sub type {
  my ($self) = @_;
  return undef unless $self->category;
  return $self->subcategory
    ? $self->category . '/' . $self->subcategory
    : $self->category;
}

sub name { shift->instanceName }

1;

=head1 SYNOPSIS

  my $markers = $api->map_data(map => 'dam');
  for my $marker (@$markers) {
      say $marker->category . '/' . $marker->subcategory;
      say "  (" . $marker->lng . ", " . $marker->lat . ")";
      say "  Behind locked door" if $marker->behindLockedDoor;
  }

=head1 DESCRIPTION

Represents a map marker from the ARC Raiders game maps.

Extends L<WWW::MetaForge::GameMapData::Result::MapMarker> with
ARC Raiders specific attributes.

=head1 INHERITED ATTRIBUTES

See L<WWW::MetaForge::GameMapData::Result::MapMarker> for base attributes
(id, lat, lng, zlayers, mapID, updated_at, added_by, last_edited_by).

=attr category

Marker category (e.g., "arc", "containers", "locations", "events").

=attr subcategory

Marker subcategory (e.g., "tick", "pop", "base_container", "player_spawn").

=attr instanceName

Optional instance name for the marker.

=attr behindLockedDoor

Boolean indicating if marker is behind a locked door.

=attr eventConditionMask

Event condition bitmask.

=attr lootAreas

Loot area data (can be null, string, or array).

=method type

Returns "category/subcategory" string.

=method name

Alias for C<instanceName>.

=cut
