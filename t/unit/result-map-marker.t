#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS;
use FindBin;

use_ok('WWW::MetaForge::ArcRaiders::Result::MapMarker');

# Load fixture
my $fixture_file = "$FindBin::Bin/../fixtures/map-data-dam.json";
open my $fh, '<', $fixture_file or die "Cannot open $fixture_file: $!";
my $json = do { local $/; <$fh> };
close $fh;

my $data = decode_json($json);
ok($data->{allData}, 'Fixture has allData');
ok(scalar @{$data->{allData}} >= 5, 'Fixture has at least 5 markers');

subtest 'arc/tick marker' => sub {
  my $tick_data = $data->{allData}[0];
  my $tick = WWW::MetaForge::ArcRaiders::Result::MapMarker->from_hashref($tick_data);

  isa_ok($tick, 'WWW::MetaForge::ArcRaiders::Result::MapMarker');
  isa_ok($tick, 'WWW::MetaForge::GameMapData::Result::MapMarker');

  is($tick->id, 'd1098bdf-fe93-1eb1-8c09-f5f8803c9386', 'id correct');
  is($tick->map_id, 'dam', 'map_id correct');
  is($tick->category, 'arc', 'category correct');
  is($tick->subcategory, 'tick', 'subcategory correct');
  is($tick->type, 'arc/tick', 'type combines category/subcategory');

  # Coordinates (lng -> x, lat -> y)
  ok(defined $tick->x, 'has x coordinate');
  ok(defined $tick->y, 'has y coordinate');
  cmp_ok($tick->x, '>', 3000, 'x coordinate reasonable (from lng)');
  cmp_ok($tick->y, '>', 1000, 'y coordinate reasonable (from lat)');

  is($tick->behind_locked_door, 0, 'not behind locked door');
  is($tick->event_condition_mask, 1, 'event_condition_mask correct');
  ok(defined $tick->last_updated, 'has last_updated');
};

subtest 'container marker' => sub {
  my $container_data = $data->{allData}[4];
  my $container = WWW::MetaForge::ArcRaiders::Result::MapMarker->from_hashref($container_data);

  is($container->category, 'containers', 'container category correct');
  is($container->subcategory, 'base_container', 'container subcategory correct');
  is($container->type, 'containers/base_container', 'container type correct');
  is($container->map_id, 'dam', 'map_id correct');
};

subtest '_raw accessor' => sub {
  my $marker = WWW::MetaForge::ArcRaiders::Result::MapMarker->from_hashref($data->{allData}[0]);

  ok($marker->_raw, 'has _raw accessor');
  is(ref $marker->_raw, 'HASH', '_raw is hashref');
  is($marker->_raw->{mapID}, 'dam', '_raw contains original data');
};

subtest 'coordinates method' => sub {
  my $marker = WWW::MetaForge::ArcRaiders::Result::MapMarker->from_hashref($data->{allData}[0]);
  my $coords = $marker->coordinates;

  is(ref $coords, 'HASH', 'coordinates returns hashref');
  ok(exists $coords->{x}, 'coordinates has x');
  ok(exists $coords->{y}, 'coordinates has y');
};

subtest 'boolean behind_locked_door' => sub {
  # Test with false value
  my $marker1 = WWW::MetaForge::ArcRaiders::Result::MapMarker->from_hashref({
    id => 'test-1', mapID => 'dam', category => 'test', subcategory => 'test',
    lat => 100, lng => 200, behindLockedDoor => 0,
  });
  is($marker1->behind_locked_door, 0, 'behind_locked_door false');

  # Test with true value
  my $marker2 = WWW::MetaForge::ArcRaiders::Result::MapMarker->from_hashref({
    id => 'test-2', mapID => 'dam', category => 'test', subcategory => 'test',
    lat => 100, lng => 200, behindLockedDoor => 1,
  });
  is($marker2->behind_locked_door, 1, 'behind_locked_door true');
};

done_testing;
