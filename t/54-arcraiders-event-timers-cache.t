#!/usr/bin/env perl
use strict;
use warnings;

# The clock of this test: time() is frozen at a moment inside the window of
# the fixture, before its first run. The library reads time() (cache age,
# staleness), so the fixture must not depend on the real date: its own
# runs lie in the past as soon as its last run has passed, and then even the
# fresh response would count as stale. The override has to be in place before
# the library is compiled.
my $NOW;
BEGIN {
  require Time::Local;
  $NOW = Time::Local::timegm(0, 30, 20, 2, 10, 2026);    # 2026-11-02 20:30:00 UTC
  no warnings 'once';
  *CORE::GLOBAL::time = sub () { $NOW };
}

use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/lib";
use JSON::MaybeXS;
use Path::Tiny;
use MockUA;
use WWW::MetaForge::Cache;
use WWW::MetaForge::ArcRaiders;

# A cached events-schedule response (event_timers_cached / event_timers_raw)
# is fetched again as soon as a timer that still had a run ahead when the
# entry was written has started its last run: from then on its next_time
# would be undef. Timers whose last run lay before the entry's timestamp do
# not count; without any timer that had a run ahead the entry is always
# stale. Starts are compared in seconds (int of ms / 1000), timers are
# grouped by name+map (+region, when the records carry one).
#
# All times are relative to the frozen time(), see above. The cached entries
# hold records built from fixture records; what a fresh request delivers is
# the fixture itself: 35 timers out of 171 records, all with a run ahead of
# the frozen time. With a frozen clock the tests cannot straddle a full hour
# (event_timers_hourly is valid per running hour).

my $fixture = path("$FindBin::Bin/fixtures/events-schedule.json")->slurp_utf8;
my $json    = JSON::MaybeXS->new;
my @records = @{ $json->decode($fixture)->{data} };

# two templates of different name+map, taken from the fixture
my $tpl_a = $records[0];
my ($tpl_b) = grep { $_->{name} ne $tpl_a->{name} || $_->{map} ne $tpl_a->{map} } @records;

# the records of one timer: an earlier run and the last run starting at $last
# (epoch seconds), so the last start is told from the first
sub timer {
  my ($tpl, $last, %over) = @_;
  return map {
    +{ %$tpl, startTime => $_ * 1000, endTime => ($_ + 1800) * 1000, %over }
  } ($last - 7200, $last);
}

sub new_api {
  my (%args) = @_;
  my $ua  = MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures");
  my $api = WWW::MetaForge::ArcRaiders->new(
    ua        => $ua,
    cache_dir => tempdir(CLEANUP => 1),
    use_cache => 1,
    %args,
  );
  return ($api, $ua);
}

sub timer_requests { my ($ua) = @_; return scalar grep { m{/events-schedule} } $ua->requests }

# Write the events-schedule entry for %$params with the given records, as
# written $age seconds ago
sub seed {
  my ($api, $params, $records, $age) = @_;
  my $response = $json->decode($fixture);
  $response->{data} = $records;
  $api->cache->set('event_timers', $params, $response);

  my @files = $api->cache->cache_dir->children(qr/^event_timers_[0-9a-f]{32}\.v2\.json$/);
  is(scalar @files, 1, 'one event_timers cache file (not the hourly one)');
  my $cjson = $api->cache->json;
  my $entry = $cjson->decode($files[0]->slurp_raw);
  $entry->{timestamp} = time() - $age;
  $files[0]->spew_raw($cjson->encode($entry));
}

sub by_name {
  my ($timers) = @_;
  return { map { join('|', $_->name, $_->map) => $_ } @$timers };
}

subtest 'every timer has a run ahead: served from the cache without a request' => sub {
  my ($api, $ua) = new_api();
  my $now = time();
  seed($api, {}, [ timer($tpl_a, $now + 3600), timer($tpl_b, $now + 7200) ], 0);

  my $timers = $api->event_timers_cached;
  is(scalar @$timers, 2, 'event_timers_cached: the two cached timers');
  my $by = by_name($timers);
  my $key_a = join '|', $tpl_a->{name}, $tpl_a->{map};
  my $key_b = join '|', $tpl_b->{name}, $tpl_b->{map};
  is($by->{$key_a}->next_time->start->epoch, $now + 3600, 'timer A: next_time is its cached last run');
  is($by->{$key_b}->next_time->start->epoch, $now + 7200, 'timer B: next_time is its cached last run');

  my $raw = $api->event_timers_raw;
  is(scalar @{ $raw->{data} }, 4, 'event_timers_raw: the four cached records');
  is(timer_requests($ua), 0, 'no request at all - both methods share the entry');
};

subtest 'a timer ran out of runs: event_timers_cached fetches again' => sub {
  my ($api, $ua) = new_api();
  my $now = time();
  seed($api, {}, [ timer($tpl_a, $now - 60), timer($tpl_b, $now + 3600) ], 7200);

  my $timers = $api->event_timers_cached;
  is(timer_requests($ua), 1, 'exactly one request');
  is(scalar @$timers, 35, 'the 35 timers of the fresh response, not the 2 cached ones');

  my $entry = $api->cache->get_entry('event_timers', {});
  is(scalar @{ $entry->{data}{data} }, 171, 'the entry was overwritten with the fresh records');
  cmp_ok($entry->{timestamp}, '>=', $now, 'with a fresh timestamp');

  $api->event_timers_cached;
  is(timer_requests($ua), 1, 'the overwritten entry is fresh data: no further request');
};

subtest 'a timer ran out of runs: event_timers_raw fetches again' => sub {
  my ($api, $ua) = new_api();
  my $now = time();
  seed($api, {}, [ timer($tpl_a, $now - 60), timer($tpl_b, $now + 3600) ], 7200);

  my $raw = $api->event_timers_raw;
  is(timer_requests($ua), 1, 'exactly one request');
  is(scalar @{ $raw->{data} }, 171, 'the 171 records of the fresh response');
  is($raw->{region}, 'europe', 'the whole response, as the fixture has it');
};

subtest 'a timer that ran out before the entry was written does not count' => sub {
  my ($api, $ua) = new_api();
  my $now = time();
  seed($api, {}, [ timer($tpl_a, $now - 60), timer($tpl_b, $now + 3600) ], 0);

  is(scalar @{ $api->event_timers_cached }, 2, 'served from the cache');
  is(scalar @{ $api->event_timers_raw->{data} }, 4, 'raw too');
  is(timer_requests($ua), 0, 'no request - no endless reloading of a window that never had more');
};

subtest 'no timer had a run ahead: always stale' => sub {
  {
    my ($api, $ua) = new_api();
    my $now = time();
    seed($api, {}, [ timer($tpl_a, $now - 60), timer($tpl_b, $now - 30) ], 0);

    is(scalar @{ $api->event_timers_cached }, 35, 'all runs past: the fresh response');
    is(timer_requests($ua), 1, 'one request');
  }
  {
    my ($api, $ua) = new_api();
    seed($api, {}, [], 0);

    is(scalar @{ $api->event_timers_cached }, 35, 'empty data: the fresh response');
    is(timer_requests($ua), 1, 'one request');
  }
};

subtest 'event_timers_hourly entry survives the refresh' => sub {
  my ($api, $ua) = new_api();
  $api->event_timers_hourly;
  is(timer_requests($ua), 1, 'event_timers_hourly fetches');

  my $now = time();
  seed($api, {}, [ timer($tpl_a, $now - 60), timer($tpl_b, $now + 3600) ], 7200);

  $api->event_timers_cached;
  is(timer_requests($ua), 2, 'the stale entry is fetched again: two requests in all');
  is(scalar($api->cache->cache_dir->children(qr/^event_timers_hourly_/)), 1,
    'the event_timers_hourly cache file is still there');

  $api->event_timers_hourly;
  is(timer_requests($ua), 2, 'event_timers_hourly is still served from its entry');

  my $entry = $api->cache->get_entry('event_timers', {});
  is(scalar @{ $entry->{data}{data} }, 171, 'the event_timers entry holds the fresh records');
  cmp_ok($entry->{timestamp}, '>=', $now, 'with a fresh timestamp');
};

subtest 'region => all: the timers are told apart by region' => sub {
  my %params = (region => 'all');
  my $now    = time();
  my @europe = timer($tpl_a, $now - 60,   map => 'Dam', region => 'europe');
  my @na     = timer($tpl_a, $now + 3600, map => 'Dam', region => 'north-america');

  {
    my ($api, $ua) = new_api();
    seed($api, \%params, [ @europe, @na ], 7200);

    my $timers = $api->event_timers_cached(%params);
    is(timer_requests($ua), 1, 'the europe timer ran out of runs: one request');
    # fresh response = t/fixtures/events-schedule-region-all.json: 830 records, 180 name+map+region groups
    is(scalar @$timers, 180, 'the fresh response');
  }
  {
    # same records without the region key: one timer, its last run is ahead
    my ($api, $ua) = new_api();
    my @flat = map { my %r = %$_; delete $r{region}; \%r } @europe, @na;
    seed($api, \%params, \@flat, 7200);

    is(scalar @{ $api->event_timers_cached(%params) }, 1, 'without region: a single timer');
    is(timer_requests($ua), 0, 'and it has a run ahead: served from the cache');
  }
};

subtest 'boundary: the last start at this very second' => sub {
  {
    my ($api, $ua) = new_api();
    my $now = time();
    seed($api, {}, [ timer($tpl_a, $now), timer($tpl_b, $now + 3600) ], 7200);

    $api->event_timers_cached;
    is(timer_requests($ua), 1, 'last start == time(): stale');
  }
  {
    my ($api, $ua) = new_api();
    my $now = time();
    seed($api, {}, [ timer($tpl_a, $now + 60), timer($tpl_b, $now + 3600) ], 7200);

    is(scalar @{ $api->event_timers_cached }, 2, 'last start one minute ahead: the cached timers');
    is(timer_requests($ua), 0, 'no request');
  }
};

subtest 'a TTL for event_timers applies on top' => sub {
  my $cache_dir = tempdir(CLEANUP => 1);
  my $ua  = MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures");
  my $api = WWW::MetaForge::ArcRaiders->new(
    ua        => $ua,
    use_cache => 1,
    cache     => WWW::MetaForge::Cache->new(cache_dir => $cache_dir, ttl => { event_timers => 60 }),
  );
  my $now = time();
  seed($api, {}, [ timer($tpl_a, $now + 3600) ], 120);

  is(scalar @{ $api->event_timers_cached }, 35, 'entry older than the TTL: the fresh response');
  is(timer_requests($ua), 1, 'one request although the timer has a run ahead');
};

subtest 'use_cache => 0 never looks into the cache' => sub {
  my ($api, $ua) = new_api(use_cache => 0);
  my $now = time();
  seed($api, {}, [ timer($tpl_a, $now + 3600), timer($tpl_b, $now + 7200) ], 0);

  is(scalar @{ $api->event_timers_cached }, 35, 'event_timers_cached: the fresh response');
  is(scalar @{ $api->event_timers_raw->{data} }, 171, 'event_timers_raw: the fresh records');
  $api->event_timers_cached;
  is(timer_requests($ua), 3, 'every call is a request');
};

done_testing;
