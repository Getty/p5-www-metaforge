#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/lib";

use WWW::MetaForge::ArcRaiders;
use WWW::MetaForge::GameMapData;
use MockUA;

# Fixture t/fixtures/map-data-pendola-pass.json is a verbatim selection (one
# record per category) of the live game-map-data response for pendola-pass.

# map_data goes through a child GameMapData that builds its own LWP::UserAgent
# unless one is injected, so MockUA is handed to it explicitly (offline).
my $ua        = MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures");
my $cache_dir = tempdir(CLEANUP => 1);
my $api       = WWW::MetaForge::ArcRaiders->new(
  ua            => $ua,
  cache_dir     => $cache_dir,
  use_cache     => 0,
  game_map_data => WWW::MetaForge::GameMapData->new(
    ua           => $ua,
    cache_dir    => $cache_dir,
    use_cache    => 0,
    marker_class => 'WWW::MetaForge::ArcRaiders::Result::MapMarker',
  ),
);

# id => expected values, copied from the fixture records
my %expect = (
  '0023ebfc-b483-4843-a09c-7fb91bdc4100' => {
    updated_at => '2026-10-08T10:49:34.035608+00:00',
    lat => 8663.6, lng => 9630.08, category => 'arc', subcategory => 'sentinel',
    instanceName => undef,
  },
  '002ff375-4e66-49ea-8476-dbdbc6282bd4' => {
    updated_at => '2026-10-08T10:49:34.035608+00:00',
    lat => 7487.09, lng => 9179.2, category => 'containers',
    subcategory => 'base_container', instanceName => 'Server Rack',
  },
  '01149bfe-eed0-43a2-b8d1-23c8e39d5ef5' => {
    updated_at => '2026-10-08T10:49:34.035608+00:00',
    lat => 12084.79, lng => 9805.88, category => 'nature',
    subcategory => 'candleberries', instanceName => undef,
  },
  '0227a844-7f15-4a88-bd39-9b8539c0c159' => {
    updated_at => '2026-10-09T09:07:51.21474+00:00',
    lat => 8052.1, lng => 5847.21, category => 'events',
    subcategory => 'emperor_payload', instanceName => undef,
  },
  '0b96bb89-2df1-4fd6-9866-2368dd792fe0' => {
    updated_at => '2026-10-08T11:45:54.177261+00:00',
    lat => 8630.32, lng => 7039.67, category => 'locations',
    subcategory => 'extraction', instanceName => 'Reckless Transceiver',
  },
  'e5d25a47-893e-4884-8bce-acb7a4bb6518' => {
    added_by => 'MisterWombat',
    updated_at => '2026-10-09T09:07:51.21474+00:00',
    lat => 7123.95, lng => 10224.9, category => 'quests',
    subcategory => 'exploring-pendola-pass',
    instanceName => 'Search Control Room for power',
  },
);

my $markers = $api->map_data(map => 'pendola-pass');

subtest 'pendola-pass markers load through MockUA' => sub {
  is(ref $markers, 'ARRAY', 'returns arrayref');
  is(scalar @$markers, 6, 'one marker per fixture record');
  isa_ok($_, 'WWW::MetaForge::ArcRaiders::Result::MapMarker') for @$markers;
  is_deeply([ map { $_->id } @$markers ], [ sort keys %expect ],
    'ids are those of the fixture records, in order');
};

subtest 'every marker belongs to pendola-pass' => sub {
  is($_->mapID, 'pendola-pass', 'mapID of ' . $_->id) for @$markers;
  is($_->_raw->{mapID}, 'pendola-pass', '_raw mapID of ' . $_->id) for @$markers;
};

subtest 'attributes map the right API keys' => sub {
  for my $m (@$markers) {
    my $e = $expect{ $m->id } or next;
    my $id = $m->id;
    is($m->lat, $e->{lat}, "lat of $id");
    is($m->lng, $e->{lng}, "lng of $id");
    is($m->category, $e->{category}, "category of $id");
    is($m->subcategory, $e->{subcategory}, "subcategory of $id");
    is($m->instanceName, $e->{instanceName}, "instanceName of $id");
    is($m->zlayers, 1, "zlayers of $id");
    is($m->added_by, $e->{added_by} // 'MetaForge', "added_by of $id");
    is($m->updated_at, $e->{updated_at}, "updated_at of $id");
    is($m->behindLockedDoor, 0, "behindLockedDoor of $id");
  }
};

subtest 'convenience accessors follow the mapped fields' => sub {
  my ($rack) = grep { $_->id eq '002ff375-4e66-49ea-8476-dbdbc6282bd4' } @$markers;
  is($rack->type, 'containers/base_container', 'type is category/subcategory');
  is($rack->name, 'Server Rack', 'name is instanceName');
};

done_testing;
