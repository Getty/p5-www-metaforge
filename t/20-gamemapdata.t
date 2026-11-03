#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/lib";

use_ok('WWW::MetaForge::GameMapData');

my $cache_dir = tempdir(CLEANUP => 1);
my $api;

if ($ENV{WWW_METAFORGE_USE_LIVE_API}) {
  diag("Using LIVE API for GameMapData tests");
  $api = WWW::MetaForge::GameMapData->new(
    cache_dir => $cache_dir,
    use_cache => 0,
    debug     => $ENV{WWW_METAFORGE_GAMEMAPDATA_DEBUG},
  );
} else {
  diag("Using MockUA for GameMapData tests (set WWW_METAFORGE_USE_LIVE_API=1 for real API)");
  require MockUA;
  $api = WWW::MetaForge::GameMapData->new(
    ua        => MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures"),
    cache_dir => $cache_dir,
    use_cache => 0,
  );
}

isa_ok($api, 'WWW::MetaForge::GameMapData');

subtest 'Request factory' => sub {
  my $req = $api->request->map_data(map => 'dam');
  isa_ok($req, 'HTTP::Request', "map_data request");
  is($req->method, 'GET', "is GET");
  like($req->uri, qr/mapID=dam/, "includes mapID");
};

subtest 'map_data returns markers' => sub {
  my $markers = eval { $api->map_data(map => 'dam') };
  return fail("API error: $@") if $@;

  ok(ref $markers eq 'ARRAY', 'returns arrayref');
  return ok(1, 'empty response is valid') unless @$markers;

  my $marker = $markers->[0];
  isa_ok($marker, 'WWW::MetaForge::GameMapData::Result::MapMarker');
  ok($marker->can('x'), 'has x accessor');
  ok($marker->can('y'), 'has y accessor');
  ok($marker->can('type'), 'has type accessor');

  diag("Sample: " . ($marker->type // 'undef') . " at (" . ($marker->x // '?') . ", " . ($marker->y // '?') . ")");
};

subtest 'fixture markers map the API keys' => sub {
  plan skip_all => 'fixture values only hold offline' if $ENV{WWW_METAFORGE_USE_LIVE_API};

  my $markers = $api->map_data(map => 'dam');
  is(scalar @$markers, 8, 'one marker per record of the fixture');
  is($_->mapID, 'dam', 'mapID of ' . $_->id) for @$markers;

  my %by_id = map { $_->id => $_ } @$markers;
  my $generator = $by_id{'00e5f6e7-d55b-97b1-385b-34e4741fa2e3'};
  is($generator->lat, 2040.55, 'lat');
  is($generator->lng, 3657.3, 'lng');
  is($generator->community, 1, 'community');
  is($generator->source_id, '410d0e8a63efb9f88699659d', 'source_id');
  is($by_id{'1c08e459-3da5-d1f7-e1bf-10e442fa6fc4'}->route_id, '10e6170b3c30915aa28be9c1', 'route_id');
  is($by_id{'0041bc88-c9e8-48e1-9d1f-38a35e688761'}->community, 0, 'community false');
  is($generator->_raw->{lootAreas}, 'Industrial, Security', '_raw carries the record');
};

subtest 'map_data_raw returns unwrapped data' => sub {
  my $raw = eval { $api->map_data_raw(map => 'dam') };
  return fail("API error: $@") if $@;

  ok(defined $raw, 'returns data');
  ok(ref $raw eq 'ARRAY' || ref $raw eq 'HASH', 'returns array or hash');
};

subtest 'Cache works' => sub {
  my $cached_api;
  if ($ENV{WWW_METAFORGE_USE_LIVE_API}) {
    $cached_api = WWW::MetaForge::GameMapData->new(
      cache_dir => $cache_dir,
      use_cache => 1,
    );
  } else {
    require MockUA;
    $cached_api = WWW::MetaForge::GameMapData->new(
      ua        => MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures"),
      cache_dir => $cache_dir,
      use_cache => 1,
    );
  }

  $cached_api->clear_cache('map_data');

  my $first = eval { $cached_api->map_data(map => 'dam') };
  return fail("API error: $@") if $@;

  my $second = $cached_api->map_data(map => 'dam');
  is(scalar @$first, scalar @$second, 'cached response has same count');
};

subtest 'Custom marker_class' => sub {
  # Just verify the attribute works
  my $custom = WWW::MetaForge::GameMapData->new(
    marker_class => 'WWW::MetaForge::GameMapData::Result::MapMarker',
  );
  is($custom->marker_class, 'WWW::MetaForge::GameMapData::Result::MapMarker', 'marker_class is settable');
};

done_testing;
