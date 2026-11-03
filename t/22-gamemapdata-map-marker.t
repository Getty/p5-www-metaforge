#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use JSON::MaybeXS qw( decode_json );
use Path::Tiny;

use WWW::MetaForge::GameMapData::Result::MapMarker;

subtest 'from_hashref with MetaForge format' => sub {
  my $data = {
    id             => 'test-uuid-1234',
    lat            => 1259,
    lng            => 3312.858,
    zlayers        => 2147483647,
    mapID          => 'dam',
    updated_at     => '2025-10-15T12:03:27.657044+00:00',
    added_by       => 'testuser',
    last_edited_by => 'editor',
  };

  my $marker = WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref($data);

  is($marker->id, 'test-uuid-1234', 'id');
  is($marker->lat, 1259, 'lat');
  is($marker->lng, 3312.858, 'lng');
  is($marker->zlayers, 2147483647, 'zlayers');
  is($marker->mapID, 'dam', 'mapID');
  is($marker->updated_at, '2025-10-15T12:03:27.657044+00:00', 'updated_at');
  is($marker->added_by, 'testuser', 'added_by');
  is($marker->last_edited_by, 'editor', 'last_edited_by');
};

subtest 'convenience accessors x/y/z' => sub {
  my $data = {
    id      => 'test-2',
    lat     => 100,
    lng     => 200,
    zlayers => 5,
    mapID   => 'dam',
  };

  my $marker = WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref($data);

  is($marker->x, 200, 'x is alias for lng');
  is($marker->y, 100, 'y is alias for lat');
  is($marker->z, 5, 'z is alias for zlayers');
};

subtest 'coordinates method' => sub {
  my $marker = WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref({
    id    => 'test-3',
    lat   => 20,
    lng   => 10,
    mapID => 'dam',
  });

  my $coords = $marker->coordinates;
  is_deeply($coords, { x => 10, y => 20 }, 'coordinates without z');

  my $marker_z = WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref({
    id      => 'test-4',
    lat     => 20,
    lng     => 10,
    zlayers => 5,
    mapID   => 'dam',
  });

  my $coords_z = $marker_z->coordinates;
  is_deeply($coords_z, { x => 10, y => 20, z => 5 }, 'coordinates with z');
};

subtest 'base class type and name return undef' => sub {
  my $marker = WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref({
    id    => 'test-5',
    lat   => 100,
    lng   => 200,
    mapID => 'dam',
  });

  is($marker->type, undef, 'base class type returns undef');
  is($marker->name, undef, 'base class name returns undef');
};

subtest '_raw preserved' => sub {
  my $data = {
    id           => 'test-6',
    lat          => 100,
    lng          => 200,
    mapID        => 'dam',
    custom_field => 'custom_value',
  };

  my $marker = WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref($data);

  is($marker->_raw->{custom_field}, 'custom_value', '_raw contains original data');
  is($marker->_raw->{mapID}, 'dam', '_raw contains mapID');
};

subtest 'optional fields can be undef' => sub {
  my $marker = WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref({
    id    => 'test-7',
    lat   => 100,
    lng   => 200,
    mapID => 'dam',
  });

  is($marker->zlayers, undef, 'zlayers can be undef');
  is($marker->updated_at, undef, 'updated_at can be undef');
  is($marker->added_by, undef, 'added_by can be undef');
  is($marker->last_edited_by, undef, 'last_edited_by can be undef');
};

# Records of t/fixtures/map-data-dam.json, unchanged from the live response.
my %record = map { $_->{id} => $_ }
  @{ decode_json( path("$FindBin::Bin/fixtures/map-data-dam.json")->slurp_raw )->{allData} };

subtest 'community, sourceID and routeID of live records' => sub {
  my $from = sub { WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref($record{ $_[0] }) };

  my $generator = $from->('00e5f6e7-d55b-97b1-385b-34e4741fa2e3');   # community, sourceID
  is($generator->community, 1, 'community true');
  is($generator->source_id, '410d0e8a63efb9f88699659d', 'source_id is sourceID');
  is($generator->route_id, undef, 'route_id undef without routeID');
  is($generator->last_edited_by, 'soloboom88', 'last_edited_by');
  is($generator->added_by, undef, 'added_by is null');

  my $bastion = $from->('1c08e459-3da5-d1f7-e1bf-10e442fa6fc4');     # community, routeID
  is($bastion->community, 1, 'community true on the route marker');
  is($bastion->route_id, '10e6170b3c30915aa28be9c1', 'route_id is routeID');
  is($bastion->source_id, undef, 'source_id undef without sourceID');

  my $snitch = $from->('0041bc88-c9e8-48e1-9d1f-38a35e688761');      # MetaForge, sourceID and routeID
  is($snitch->community, 0, 'community false');
  is($snitch->source_id, '89136abdda492e1aa58e8926', 'source_id');
  is($snitch->route_id, '57777f3e6eb5160afe01f31d', 'route_id');
  is($snitch->added_by, 'MetaForge', 'added_by');

  is($snitch->_raw->{sourceID}, $snitch->source_id, '_raw keeps the API key sourceID');
  is($snitch->_raw->{routeID}, $snitch->route_id, '_raw keeps the API key routeID');
};

subtest 'community coercion' => sub {
  my %base = ( id => 'c', lat => 1, lng => 2, mapID => 'dam' );
  is(WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref({ %base, community => JSON::MaybeXS::true })->community, 1, 'JSON true');
  is(WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref({ %base, community => JSON::MaybeXS::false })->community, 0, 'JSON false');
  is(WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref({ %base })->community, 0, 'absent key is false');
  is(WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref({ %base })->source_id, undef, 'source_id undef when absent');
  is(WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref({ %base })->route_id, undef, 'route_id undef when absent');
};

done_testing;
