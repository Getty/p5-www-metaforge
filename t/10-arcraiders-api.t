#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/lib";

use_ok('WWW::MetaForge::ArcRaiders');

my $cache_dir = tempdir(CLEANUP => 1);
my $api;
my $using_mock = 0;

if ($ENV{WWW_METAFORGE_USE_LIVE_API}) {
  diag("Using LIVE API");
  $api = WWW::MetaForge::ArcRaiders->new(
    cache_dir => $cache_dir,
    use_cache => 0,
    debug     => $ENV{WWW_METAFORGE_ARCRAIDERS_DEBUG},
  );
} else {
  diag("Using MockUA (set WWW_METAFORGE_USE_LIVE_API=1 for real API tests)");
  require MockUA;
  $api = WWW::MetaForge::ArcRaiders->new(
    ua        => MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures"),
    cache_dir => $cache_dir,
    use_cache => 0,
    debug     => $ENV{WWW_METAFORGE_ARCRAIDERS_DEBUG},
  );
  $using_mock = 1;
}

isa_ok($api, 'WWW::MetaForge::ArcRaiders');

# Helper to test any result object has basic structure
sub test_result_object {
  my ($obj, $class, $required_attrs) = @_;
  isa_ok($obj, $class);
  ok($obj->can('_raw'), 'has _raw accessor');
  ok(ref $obj->_raw eq 'HASH', '_raw is hashref');
  for my $attr (@$required_attrs) {
    ok($obj->can($attr), "has $attr accessor");
  }
}

subtest 'Request factory creates valid HTTP::Request objects' => sub {
  for my $method (qw(items arcs quests traders event_timers map_data)) {
    my $req = $api->request->$method(test => 'value');
    isa_ok($req, 'HTTP::Request', "$method request");
    is($req->method, 'GET', "$method is GET");
    like($req->uri, qr/test=value/, "$method includes params");
  }
};

subtest 'Traders endpoint returns valid structure' => sub {
  my $traders = eval { $api->traders };
  return fail("API error: $@") if $@;

  ok(ref $traders eq 'ARRAY', 'returns arrayref');
  return ok(1, 'empty response is valid') unless @$traders;

  my $trader = $traders->[0];
  test_result_object($trader, 'WWW::MetaForge::ArcRaiders::Result::Trader',
    [qw(name inventory)]);

  ok(ref $trader->inventory eq 'ARRAY', 'inventory is array');
  diag("Sample: " . $trader->name . " (" . @{$trader->inventory} . " items)");
};

subtest 'Items endpoint returns valid structure' => sub {
  my $items = eval { $api->items };
  return fail("API error: $@") if $@;

  ok(ref $items eq 'ARRAY', 'returns arrayref');
  return ok(1, 'empty response is valid') unless @$items;

  my $item = $items->[0];
  test_result_object($item, 'WWW::MetaForge::ArcRaiders::Result::Item',
    [qw(id name rarity description)]);

  diag("Sample: " . ($item->name // 'undef'));
};

subtest 'Arcs endpoint returns valid structure' => sub {
  my $arcs = eval { $api->arcs };
  return fail("API error: $@") if $@;

  ok(ref $arcs eq 'ARRAY', 'returns arrayref');
  return ok(1, 'empty response is valid') unless @$arcs;

  my $arc = $arcs->[0];
  test_result_object($arc, 'WWW::MetaForge::ArcRaiders::Result::Arc',
    [qw(id name description)]);

  diag("Sample: " . ($arc->name // 'undef'));
};

subtest 'Quests endpoint returns valid structure' => sub {
  my $quests = eval { $api->quests };
  return fail("API error: $@") if $@;

  ok(ref $quests eq 'ARRAY', 'returns arrayref');
  return ok(1, 'empty response is valid') unless @$quests;

  my $quest = $quests->[0];
  test_result_object($quest, 'WWW::MetaForge::ArcRaiders::Result::Quest',
    [qw(id name)]);

  diag("Sample: " . ($quest->name // 'undef'));
};

subtest 'Event timers endpoint returns valid structure' => sub {
  my $events = eval { $api->event_timers };
  return fail("API error: $@") if $@;

  ok(ref $events eq 'ARRAY', 'returns arrayref');
  return ok(1, 'empty response is valid') unless @$events;

  my $event = $events->[0];
  test_result_object($event, 'WWW::MetaForge::ArcRaiders::Result::EventTimer',
    [qw(name map times)]);

  ok(ref $event->times eq 'ARRAY', 'times is array');
  ok($event->can('is_active_now'), 'has is_active_now method');
  ok($event->can('next_time'), 'has next_time method');

  # Test methods don't crash
  my $active = $event->is_active_now;
  ok(defined $active, 'is_active_now returns defined value');

  diag("Sample: " . ($event->name // 'undef') . " on " . ($event->map // 'undef'));
};

subtest 'Map data endpoint returns valid structure' => sub {
  my $markers = eval { $api->map_data(map => 'dam') };
  return fail("API error: $@") if $@;

  ok(ref $markers eq 'ARRAY', 'returns arrayref');
  return ok(1, 'empty response is valid') unless @$markers;

  my $marker = $markers->[0];
  test_result_object($marker, 'WWW::MetaForge::ArcRaiders::Result::MapMarker',
    [qw(name type x y)]);

  diag("Sample: " . ($marker->name // 'undef') . " at (" . ($marker->x // '?') . ", " . ($marker->y // '?') . ")");
};

subtest 'Fixture contents come through the API (offline only)' => sub {
  plan skip_all => 'fixture values only hold offline' unless $using_mock;

  my $arcs = $api->arcs;
  is(scalar @$arcs, 26, 'arcs: the whole inventory');
  is($arcs->[0]->id, 'arc-assessor', 'arcs: first id');
  is($arcs->[2]->id, 'rollbot', 'arcs: third id');
  is($arcs->[2]->data->{updated_at}, '2026-09-20T19:16:18.001037+00:00', 'arcs: data comes through');
  ok(!$arcs->[2]->data->{variants}[0]{can_fly}, 'arcs: rollbot cannot fly');
  is_deeply($arcs->[0]->loot, [], 'arcs: no loot without includeLoot=true');
  is(scalar @{ $api->arcs(includeLoot => 'true')->[2]->loot }, 14, 'arcs: includeLoot=true brings the loot of rollbot');

  my $quests = $api->quests;
  is(scalar @$quests, 40, 'quests: first page of 40');
  is($quests->[0]->id, 'a-bad-feeling', 'quests: first id');
  is($quests->[0]->manifest->{prerequisites}[0]{quest_id}, 'off-the-raider', 'quests: manifest prerequisites come through');

  my $traders = $api->traders;
  is(scalar @$traders, 5, 'traders: five inventory traders');

  is(scalar @{ $api->traders_raw->{ermal}{offers} }, 10, 'traders_raw keeps the ermal section');
  isa_ok($api->ermal, 'WWW::MetaForge::ArcRaiders::Result::Ermal');
  is(scalar @{ $api->ermal->offers }, 10, 'ermal: ten offers');

  my $markers = $api->map_data(map => 'dam');
  is(scalar @$markers, 8, 'map_data: one marker per fixture record');

  my $events = $api->event_timers;
  is(scalar @$events, 35, 'event_timers: 171 records grouped into 35 name+map groups');
  my @slots = map { @{ $_->times } } @$events;
  is(scalar @slots, 171, 'event_timers: every record is one slot');
  ok(!grep({ $_->end->epoch - $_->start->epoch != 3600 } @slots), 'event_timers: every run lasts 60 minutes');
  for my $event (@$events) {
    my @starts = map { $_->start->epoch } @{ $event->times };
    is_deeply(\@starts, [ sort { $a <=> $b } @starts ], 'event_timers: times ascending for ' . $event->name . ' | ' . $event->map)
      or last;
  }
  my ($night) = grep { $_->name eq 'Night Raid' && $_->map eq 'Stella Montis' } @$events;
  is(scalar @{ $night->times }, 21, 'event_timers: Night Raid | Stella Montis has 21 runs');
  is($night->times->[0]->start->epoch, 1793660400, 'event_timers: its first run starts Mon 2 Nov 23:00 UTC');
  ok(!defined $night->region, 'event_timers: no region without region=all');
};

subtest 'Maps list returns valid data' => sub {
  my @maps = $api->maps;
  ok(@maps > 0, 'has maps');
  ok(grep { $_ eq 'dam' } @maps, 'includes dam');

  my %names = $api->map_display_names;
  is($names{'dam'}, 'Dam', 'dam display name is Dam');

  is($api->map_display_name('dam'), 'Dam', 'map_display_name works');
  is($api->map_display_name('unknown'), 'unknown', 'unknown map returns id');
};

subtest 'Maps list is complete and ordered' => sub {
  is_deeply(
    [ $api->maps ],
    [qw( dam spaceport buried-city blue-gate riven-tides stella-montis pendola-pass )],
    'maps lists every known map in order',
  );

  my %names = $api->map_display_names;
  is($names{'pendola-pass'}, 'Pendola Pass', 'pendola-pass display name in map_display_names');
  is($api->map_display_name('pendola-pass'), 'Pendola Pass', 'map_display_name for pendola-pass');
};

subtest 'Cache works correctly' => sub {
  my %opts = (cache_dir => $cache_dir, use_cache => 1);
  if ($using_mock) {
    require MockUA;
    $opts{ua} = MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures");
  }
  my $cached_api = WWW::MetaForge::ArcRaiders->new(%opts);

  $cached_api->clear_cache('traders');

  my $first = eval { $cached_api->traders };
  return fail("API error: $@") if $@;

  my $second = $cached_api->traders;

  is(scalar @$first, scalar @$second, 'cached response has same count');
};

subtest 'Raw endpoints return unwrapped data' => sub {
  my $raw = eval { $api->traders_raw };
  return fail("API error: $@") if $@;

  ok(defined $raw, 'returns data');
  ok(ref $raw eq 'ARRAY' || ref $raw eq 'HASH', 'returns array or hash');
};

subtest 'Debug mode produces output' => sub {
  require MockUA;
  my $debug_api = WWW::MetaForge::ArcRaiders->new(
    ua        => MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures"),
    cache_dir => $cache_dir,
    use_cache => 0,
    debug     => 1,
  );

  ok($debug_api->debug, 'debug attribute is set');

  my $stderr = '';
  {
    local *STDERR;
    open STDERR, '>', \$stderr;
    eval { $debug_api->traders };
  }

  like($stderr, qr/REQUEST/, 'outputs REQUEST');
  like($stderr, qr/RESPONSE/, 'outputs RESPONSE');
};

done_testing;
