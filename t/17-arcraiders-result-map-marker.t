#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS;
use FindBin;

use_ok('WWW::MetaForge::ArcRaiders::Result::MapMarker');

# Load fixture: t/fixtures/map-data-dam.json is a selection of unchanged
# records of the live game-map-data response for dam.
my $fixture_file = "$FindBin::Bin/fixtures/map-data-dam.json";
open my $fh, '<:raw', $fixture_file or die "Cannot open $fixture_file: $!";
my $json = do { local $/; <$fh> };
close $fh;

my $data = decode_json($json);
ok($data->{allData}, 'Fixture has allData');
is(scalar @{$data->{allData}}, 8, 'Fixture has 8 markers');

my %marker = map {
  $_->{id} => WWW::MetaForge::ArcRaiders::Result::MapMarker->from_hashref($_)
} @{$data->{allData}};

subtest 'arc/bastion marker' => sub {
  my $bastion = $marker{'1c08e459-3da5-d1f7-e1bf-10e442fa6fc4'};

  isa_ok($bastion, 'WWW::MetaForge::ArcRaiders::Result::MapMarker');
  isa_ok($bastion, 'WWW::MetaForge::GameMapData::Result::MapMarker');

  is($bastion->mapID, 'dam', 'mapID correct');
  is($bastion->category, 'arc', 'category correct');
  is($bastion->subcategory, 'bastion', 'subcategory correct');
  is($bastion->type, 'arc/bastion', 'type combines category/subcategory');
  is($bastion->instanceName, undef, 'instanceName is null');

  # Coordinates (lng -> x, lat -> y)
  is($bastion->lng, 4710.14456885569, 'lng');
  is($bastion->lat, 1898.87319819898, 'lat');
  is($bastion->x, 4710.14456885569, 'x comes from lng');
  is($bastion->y, 1898.87319819898, 'y comes from lat');

  is($bastion->behindLockedDoor, 0, 'not behind locked door');
  is($bastion->eventConditionMask, 1, 'eventConditionMask correct');
  is($bastion->updated_at, '2026-09-30T08:59:38.128323+00:00', 'updated_at');
};

subtest 'marker with behindLockedDoor true' => sub {
  my $locked = $marker{'5ef8f669-8c42-f210-3c67-f6a21f2ceca3'};  # breachable_container, behindLockedDoor: true

  is($locked->category, 'containers', 'container category correct');
  is($locked->subcategory, 'breachable_container', 'breachable_container subcategory correct');
  is($locked->behindLockedDoor, 1, 'behindLockedDoor is true');
  is($locked->added_by, undef, 'added_by is null');
  is($locked->last_edited_by, 'SoloBoom88', 'last_edited_by correct');
  is($marker{'0041bc88-c9e8-48e1-9d1f-38a35e688761'}->behindLockedDoor, 0, 'a marker with behindLockedDoor false');
};

subtest 'marker with lootAreas' => sub {
  my $generator = $marker{'00e5f6e7-d55b-97b1-385b-34e4741fa2e3'};

  is($generator->category, 'containers', 'container category correct');
  is($generator->subcategory, 'base_container', 'base_container subcategory correct');
  is($generator->instanceName, 'Generator', 'instanceName correct');
  is($generator->name, 'Generator', 'name alias works');
  is($generator->lootAreas, 'Industrial, Security', 'lootAreas is a string, as the API sends it');
  is($marker{'5ef8f669-8c42-f210-3c67-f6a21f2ceca3'}->lootAreas, 'Medical, Commercial', 'lootAreas of the locked container');
  is($marker{'1c08e459-3da5-d1f7-e1bf-10e442fa6fc4'}->lootAreas, undef, 'lootAreas is null for a marker without');
};

subtest 'community, sourceID and routeID' => sub {
  my $generator = $marker{'00e5f6e7-d55b-97b1-385b-34e4741fa2e3'};
  my $bastion   = $marker{'1c08e459-3da5-d1f7-e1bf-10e442fa6fc4'};
  my $snitch    = $marker{'0041bc88-c9e8-48e1-9d1f-38a35e688761'};
  my $crate     = $marker{'000304db-d61b-4f65-a091-e650c5a2074f'};

  is($generator->community, 1, 'community marker');
  is($generator->source_id, '410d0e8a63efb9f88699659d', 'source_id comes from sourceID');
  is($generator->route_id, undef, 'route_id is null');

  is($bastion->community, 1, 'community marker with a route');
  is($bastion->route_id, '10e6170b3c30915aa28be9c1', 'route_id comes from routeID');
  is($bastion->source_id, undef, 'source_id is null');

  is($snitch->community, 0, 'MetaForge marker: community false');
  is($snitch->source_id, '89136abdda492e1aa58e8926', 'source_id of a MetaForge marker');
  is($snitch->route_id, '57777f3e6eb5160afe01f31d', 'route_id of a MetaForge marker');
  is($snitch->added_by, 'MetaForge', 'added_by');

  is($crate->community, 0, 'MetaForge container: community false');
  is($crate->eventConditionMask, undef, 'eventConditionMask is null');
  is($crate->source_id, '733273fb41c970cb62f6150c', 'source_id of the crate');

  is($marker{'1a531e8e-14f7-b285-f2fe-0df10d07d435'}->eventConditionMask, 4, 'eventConditionMask 4 on the harvester event');
  is($marker{'1a531e8e-14f7-b285-f2fe-0df10d07d435'}->type, 'events/harvester', 'type of the harvester event');
};

subtest '_raw accessor' => sub {
  my $marker = $marker{'1c08e459-3da5-d1f7-e1bf-10e442fa6fc4'};

  ok($marker->_raw, 'has _raw accessor');
  is(ref $marker->_raw, 'HASH', '_raw is hashref');
  is($marker->_raw->{mapID}, 'dam', '_raw contains original data');
};

subtest 'coordinates method' => sub {
  my $marker = $marker{'1c08e459-3da5-d1f7-e1bf-10e442fa6fc4'};
  my $coords = $marker->coordinates;

  is(ref $coords, 'HASH', 'coordinates returns hashref');
  is_deeply($coords, { x => 4710.14456885569, y => 1898.87319819898, z => 2147483647 },
    'coordinates are lng, lat and zlayers');
};

subtest 'boolean behindLockedDoor coercion' => sub {
  # Test with false value
  my $marker1 = WWW::MetaForge::ArcRaiders::Result::MapMarker->from_hashref({
    id => 'test-1', mapID => 'dam', category => 'test', subcategory => 'test',
    lat => 100, lng => 200, behindLockedDoor => 0,
  });
  is($marker1->behindLockedDoor, 0, 'behindLockedDoor false');

  # Test with true value
  my $marker2 = WWW::MetaForge::ArcRaiders::Result::MapMarker->from_hashref({
    id => 'test-2', mapID => 'dam', category => 'test', subcategory => 'test',
    lat => 100, lng => 200, behindLockedDoor => 1,
  });
  is($marker2->behindLockedDoor, 1, 'behindLockedDoor true');
};

subtest 'community coercion and defaults' => sub {
  my %base = ( id => 'c', mapID => 'dam', category => 'test', subcategory => 'test', lat => 1, lng => 2 );
  is(WWW::MetaForge::ArcRaiders::Result::MapMarker->from_hashref({ %base, community => JSON::MaybeXS::true })->community, 1, 'JSON true');
  is(WWW::MetaForge::ArcRaiders::Result::MapMarker->from_hashref({ %base, community => JSON::MaybeXS::false })->community, 0, 'JSON false');
  is(WWW::MetaForge::ArcRaiders::Result::MapMarker->from_hashref({ %base })->community, 0, 'absent key is false');
};

done_testing;
