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

# event_timers_hourly is valid while the cache entry comes from the running
# full hour (entry timestamp >= int(time/3600)*3600), else it fetches again.

# The tests span a few milliseconds; do not let them straddle a full hour. With
# under 5 s left, wait for the next hour to begin.
{
  my $left = 3600 - time % 3600;
  sleep $left + 1 if $left < 5;
}

sub new_api {
  my $ua  = MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures");
  my $api = WWW::MetaForge::ArcRaiders->new(
    ua        => $ua,
    cache_dir => tempdir(CLEANUP => 1),
    use_cache => 1,
  );
  return ($api, $ua);
}

sub timer_requests { my ($ua) = @_; return scalar grep { m{/events-schedule} } $ua->requests }

subtest 'second call in the same hour makes no request' => sub {
  my ($api, $ua) = new_api();

  $api->event_timers_hourly;
  is(timer_requests($ua), 1, 'first call fetches');

  $api->event_timers_hourly;
  is(timer_requests($ua), 1, 'second call is served from the cache');
};

subtest 'entry from before the current hour is fetched again' => sub {
  my ($api, $ua) = new_api();

  $api->event_timers_hourly;
  is(timer_requests($ua), 1, 'first call fetches');

  # rewrite the entry as written one second before the running hour began
  my @files = $api->cache->cache_dir->children(qr/^event_timers_hourly_/);
  is(scalar @files, 1, 'one hourly cache file');
  my $json  = $api->cache->json;
  my $entry = $json->decode($files[0]->slurp_raw);
  $entry->{timestamp} = int(time / 3600) * 3600 - 1;
  $files[0]->spew_raw($json->encode($entry));

  $api->event_timers_hourly;
  is(timer_requests($ua), 2, 'stale entry: fetched fresh');

  $api->event_timers_hourly;
  is(timer_requests($ua), 2, 'and the new entry is valid again');
};

done_testing;
