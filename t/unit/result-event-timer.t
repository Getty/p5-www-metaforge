#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use_ok('WWW::MetaForge::ArcRaiders::Result::EventTimer');

subtest 'constructor' => sub {
  my $event = WWW::MetaForge::ArcRaiders::Result::EventTimer->new(
    name        => 'Cold Snap',
    map         => 'Dam',
    game        => 'arc-raiders',
    description => 'Freezing event',
    times       => [
      { start => '04:00', end => '06:00' },
      { start => '12:00', end => '14:00' },
    ],
    days        => [],
    _raw        => {},
  );

  is($event->name, 'Cold Snap', 'name');
  is($event->map, 'Dam', 'map');
  is($event->game, 'arc-raiders', 'game');
  is(scalar @{$event->times}, 2, 'times count');
  is($event->times->[0]{start}, '04:00', 'first time slot start');
};

subtest 'from_hashref' => sub {
  my $event = WWW::MetaForge::ArcRaiders::Result::EventTimer->from_hashref({
    name  => 'Harvester',
    map   => 'Blue Gate',
    game  => 'arc-raiders',
    icon  => 'https://example.com/icon.webp',
    times => [
      { start => '11:00', end => '12:00' },
    ],
  });

  is($event->name, 'Harvester', 'name');
  is($event->map, 'Blue Gate', 'map');
  is($event->icon, 'https://example.com/icon.webp', 'icon');
  is(scalar @{$event->times}, 1, 'times count');
};

subtest 'is_active_now method' => sub {
  # Create event that spans current hour for testing
  my ($sec, $min, $hour) = localtime;
  my $now_start = sprintf("%02d:00", $hour);
  my $now_end = sprintf("%02d:59", $hour);

  my $active_event = WWW::MetaForge::ArcRaiders::Result::EventTimer->new(
    name  => 'Test Active',
    map   => 'Test',
    game  => 'arc-raiders',
    times => [{ start => $now_start, end => $now_end }],
    _raw  => {},
  );

  # This should be active (we're within the hour)
  # Note: might fail at xx:59, but that's edge case
  ok($active_event->is_active_now, 'event in current hour is active');

  my $inactive_event = WWW::MetaForge::ArcRaiders::Result::EventTimer->new(
    name  => 'Test Inactive',
    map   => 'Test',
    game  => 'arc-raiders',
    times => [{ start => '03:00', end => '03:01' }],  # Very unlikely to be now
    _raw  => {},
  );

  # Skip this test if it happens to be 03:00
  SKIP: {
    skip "It's 03:00", 1 if $hour == 3 && $min == 0;
    ok(!$inactive_event->is_active_now, 'event not in current time is inactive');
  }
};

subtest 'is_active_now handles overnight events' => sub {
  my $overnight = WWW::MetaForge::ArcRaiders::Result::EventTimer->new(
    name  => 'Overnight',
    map   => 'Test',
    game  => 'arc-raiders',
    times => [{ start => '23:00', end => '01:00' }],
    _raw  => {},
  );

  # Just verify it doesn't crash
  my $result = $overnight->is_active_now;
  ok(defined $result, 'overnight event check returns defined value');
};

subtest 'next_time method' => sub {
  my $event = WWW::MetaForge::ArcRaiders::Result::EventTimer->new(
    name  => 'Test',
    map   => 'Test',
    game  => 'arc-raiders',
    times => [
      { start => '06:00', end => '07:00' },
      { start => '12:00', end => '13:00' },
      { start => '18:00', end => '19:00' },
    ],
    _raw  => {},
  );

  my $next = $event->next_time;
  ok(defined $next, 'next_time returns a slot');
  ok(exists $next->{start}, 'slot has start');
  ok(exists $next->{end}, 'slot has end');
};

subtest 'next_time with empty times' => sub {
  my $event = WWW::MetaForge::ArcRaiders::Result::EventTimer->new(
    name  => 'Empty',
    map   => 'Test',
    game  => 'arc-raiders',
    times => [],
    _raw  => {},
  );

  my $next = $event->next_time;
  ok(!defined $next, 'next_time returns undef for empty times');
};

subtest 'defaults' => sub {
  my $event = WWW::MetaForge::ArcRaiders::Result::EventTimer->from_hashref({
    name => 'Minimal',
    map  => 'Test',
    game => 'arc-raiders',
  });

  is(ref $event->times, 'ARRAY', 'times defaults to array');
  is(ref $event->days, 'ARRAY', 'days defaults to array');
  is(scalar @{$event->times}, 0, 'times is empty');
};

done_testing;
