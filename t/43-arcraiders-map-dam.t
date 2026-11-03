#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use URI;
use lib "$FindBin::Bin/lib";
use RecordingUA;

use WWW::MetaForge::ArcRaiders;

# Fixture t/fixtures/map-data-dam.json: eight unchanged records of the live
# game-map-data response for dam, picked to cover community markers, a routeID,
# a sourceID, lootAreas as a string and several categories.

sub new_api {
  my $ua = RecordingUA->new(fixtures_dir => "$FindBin::Bin/fixtures");
  # No game_map_data is injected: the facade has to hand its ua on.
  my $api = WWW::MetaForge::ArcRaiders->new(
    ua        => $ua,
    cache_dir => tempdir(CLEANUP => 1),
    use_cache => 0,
  );
  return ($api, $ua);
}

subtest 'map_data runs over the injected ua' => sub {
  my ($api, $ua) = new_api();
  my $markers = $api->map_data(map => 'dam');

  is(scalar $ua->seen, 1, 'the injected ua served exactly one request');
  my ($uri) = $ua->seen_uris;
  my %query = URI->new($uri)->query_form;
  like($uri, qr{^https://metaforge\.app/api/game-map-data\?}, 'it asked the game-map-data endpoint');
  is($query{mapID}, 'dam', 'mapID=dam');
  is($query{tableID}, 'arc_map_data', 'tableID=arc_map_data');

  is($api->game_map_data->ua, $ua, 'the child GameMapData holds the very same ua object');
  is($api->game_map_data->ua, $api->ua, '... which is the facade\'s ua');
  is(scalar @$markers, 8, 'markers from the fixture');
};

subtest 'markers are ArcRaiders markers, one per allData record' => sub {
  my ($api) = new_api();
  my $markers = $api->map_data(map => 'dam');

  isa_ok($_, 'WWW::MetaForge::ArcRaiders::Result::MapMarker') for @$markers;
  is_deeply([ map { $_->id } @$markers ], [qw(
    00e5f6e7-d55b-97b1-385b-34e4741fa2e3
    0106216d-815a-be07-d2d4-f461f17ab67a
    1a531e8e-14f7-b285-f2fe-0df10d07d435
    1c08e459-3da5-d1f7-e1bf-10e442fa6fc4
    5ef8f669-8c42-f210-3c67-f6a21f2ceca3
    40b873f1-67b4-67fa-db4f-e865660e352d
    000304db-d61b-4f65-a091-e650c5a2074f
    0041bc88-c9e8-48e1-9d1f-38a35e688761
  )], 'ids in API order');
  is_deeply([ map { $_->type } @$markers ], [qw(
    containers/base_container locations/supply_station events/harvester arc/bastion
    containers/breachable_container quests/a-balanced-harvest containers/base_container arc/snitch
  )], 'several categories');
  is($_->mapID, 'dam', 'mapID of ' . $_->id) for @$markers;
};

subtest 'community, source_id, route_id, lootAreas per record' => sub {
  my ($api) = new_api();
  my %marker = map { $_->id => $_ } @{ $api->map_data(map => 'dam') };

  # id => [ community, source_id, route_id, lootAreas ], copied from the fixture
  my %expect = (
    '00e5f6e7-d55b-97b1-385b-34e4741fa2e3' => [ 1, '410d0e8a63efb9f88699659d', undef, 'Industrial, Security' ],
    '0106216d-815a-be07-d2d4-f461f17ab67a' => [ 1, undef, undef, undef ],
    '1a531e8e-14f7-b285-f2fe-0df10d07d435' => [ 1, undef, undef, undef ],
    '1c08e459-3da5-d1f7-e1bf-10e442fa6fc4' => [ 1, undef, '10e6170b3c30915aa28be9c1', undef ],
    '5ef8f669-8c42-f210-3c67-f6a21f2ceca3' => [ 1, undef, undef, 'Medical, Commercial' ],
    '40b873f1-67b4-67fa-db4f-e865660e352d' => [ 1, 'e0be15ce039272c47f0975a3', undef, undef ],
    '000304db-d61b-4f65-a091-e650c5a2074f' => [ 0, '733273fb41c970cb62f6150c', undef, undef ],
    '0041bc88-c9e8-48e1-9d1f-38a35e688761' => [ 0, '89136abdda492e1aa58e8926', '57777f3e6eb5160afe01f31d', undef ],
  );
  for my $id (sort keys %expect) {
    my ($community, $source_id, $route_id, $loot) = @{ $expect{$id} };
    my $m = $marker{$id};
    is($m->community, $community, "community of $id");
    is($m->source_id, $source_id, "source_id of $id");
    is($m->route_id, $route_id, "route_id of $id");
    is($m->lootAreas, $loot, "lootAreas of $id");
  }

  is($marker{'5ef8f669-8c42-f210-3c67-f6a21f2ceca3'}->behindLockedDoor, 1, 'the one locked marker');
  is($marker{'00e5f6e7-d55b-97b1-385b-34e4741fa2e3'}->instanceName, 'Generator', 'instanceName');
  is($marker{'00e5f6e7-d55b-97b1-385b-34e4741fa2e3'}->name, 'Generator', 'name is instanceName');
  is($marker{'00e5f6e7-d55b-97b1-385b-34e4741fa2e3'}->x, 3657.3, 'x is lng');
  is($marker{'00e5f6e7-d55b-97b1-385b-34e4741fa2e3'}->y, 2040.55, 'y is lat');
};

done_testing;
