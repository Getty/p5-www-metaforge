#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/lib";
use JSON::MaybeXS;
use Path::Tiny;
use MockUA;
use WWW::MetaForge::ArcRaiders;

# A cached weekly-trials response says which trials are active and upcoming
# for the moment the API answered. It is thrown away as soon as the first
# window boundary in it (the smaller of activeWindowEnd and nextWindowStart)
# has passed. The boundaries of the fixture are those of the day it was
# recorded; the tests set their own relative to time(), and never rely on the
# boundary of the fixture being in the future.

my $fixture = path("$FindBin::Bin/fixtures/weekly-trials.json")->slurp_utf8;
my $json    = JSON::MaybeXS->new;

# A decoded copy of the fixture with its own boundaries; the data holds one
# entry only, so a cached answer is told from a fetched one (136 entries)
sub response {
  my ($active_window_end, $next_window_start) = @_;
  my $copy = $json->decode($fixture);
  $copy->{activeWindowEnd} = $active_window_end;
  $copy->{nextWindowStart} = $next_window_start;
  $copy->{data} = [ $copy->{data}[0] ];
  return $copy;
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

sub requests_to { my ($ua, $what) = @_; return scalar grep { m{/\Q$what\E$} } $ua->requests }

subtest 'both boundaries ahead: served from the cache without a request' => sub {
  my ($api, $ua) = new_api();
  $api->cache->set('weekly_trials', {}, response(time() + 3600, time() + 7200));

  is(scalar @{ $api->weekly_trials }, 1, 'weekly_trials: the cached entry');
  is($api->weekly_trials_window->active_window_end > time(), 1, 'weekly_trials_window: the cached boundary');
  is(scalar @{ $api->weekly_trials }, 1, 'weekly_trials again');
  is(scalar($ua->requests), 0, 'no request at all - window and trials share one cache entry');
};

subtest 'boundary passed: one request, fresh data' => sub {
  my ($api, $ua) = new_api();
  $api->cache->set('weekly_trials', {}, response(time() - 60, time() + 7200));

  is(scalar @{ $api->weekly_trials }, 136, 'the fresh response, not the cached entry');
  is(requests_to($ua, 'weekly-trials'), 1, 'exactly one request');
};

subtest 'boundary passed: the window call fetches too' => sub {
  my ($api, $ua) = new_api();
  $api->cache->set('weekly_trials', {}, response(time() - 60, time() + 7200));

  my $window = $api->weekly_trials_window;
  is($window->active_window_end, 1793700000, 'the boundary of the fresh response');
  is(requests_to($ua, 'weekly-trials'), 1, 'exactly one request');
};

subtest 'the smaller of the two boundaries counts' => sub {
  {
    my ($api, $ua) = new_api();
    $api->cache->set('weekly_trials', {}, response(time() + 3600, time() - 60));
    $api->weekly_trials;
    is(requests_to($ua, 'weekly-trials'), 1, 'nextWindowStart passed, activeWindowEnd ahead: stale');
  }
  {
    my ($api, $ua) = new_api();
    $api->cache->set('weekly_trials', {}, response(time() - 60, time() + 3600));
    $api->weekly_trials;
    is(requests_to($ua, 'weekly-trials'), 1, 'activeWindowEnd passed, nextWindowStart ahead: stale');
  }
  {
    my ($api, $ua) = new_api();
    $api->cache->set('weekly_trials', {}, response(time() - 60, time() - 30));
    $api->weekly_trials;
    is(requests_to($ua, 'weekly-trials'), 1, 'both passed: stale');
  }
};

subtest 'use_cache => 0 never looks into the cache' => sub {
  my ($api, $ua) = new_api(use_cache => 0);
  $api->cache->set('weekly_trials', {}, response(time() + 3600, time() + 7200));

  is(scalar @{ $api->weekly_trials }, 136, 'the fresh response, not the cached entry');
  $api->weekly_trials;
  $api->weekly_trials_window;
  is(requests_to($ua, 'weekly-trials'), 3, 'every call is a request');
};

subtest 'hideout stays cached' => sub {
  my ($api, $ua) = new_api();
  my $first  = $api->hideout;
  my $second = $api->hideout;
  is(scalar @$second, 9, 'nine stations');
  is(requests_to($ua, 'hideout'), 1, 'two calls, one request');
  is_deeply([ map { $_->id } @$second ], [ map { $_->id } @$first ], 'same stations');

  my ($uncached, $ua2) = new_api(use_cache => 0);
  $uncached->hideout for 1 .. 2;
  is(requests_to($ua2, 'hideout'), 2, 'use_cache => 0: two calls, two requests');
};

done_testing;
