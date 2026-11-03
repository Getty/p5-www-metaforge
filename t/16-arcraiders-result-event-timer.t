#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use DateTime;
use FindBin;
use lib "$FindBin::Bin/lib";
use JSON::MaybeXS;
use Path::Tiny;
use FrozenClock;

use_ok('WWW::MetaForge::ArcRaiders');
use_ok('WWW::MetaForge::ArcRaiders::Result::EventTimer');
use_ok('WWW::MetaForge::ArcRaiders::Result::EventTimer::TimeSlot');

my $EventTimer = 'WWW::MetaForge::ArcRaiders::Result::EventTimer';
my $TimeSlot   = 'WWW::MetaForge::ArcRaiders::Result::EventTimer::TimeSlot';

# The byte-faithful /events-schedule response: 171 records, one per run
my $envelope = JSON::MaybeXS->new->decode(path("$FindBin::Bin/fixtures/events-schedule.json")->slurp_utf8);
my @records  = @{ $envelope->{data} };

sub records_of {
  my ($name, $map) = @_;
  return grep { $_->{name} eq $name && $_->{map} eq $map } @records;
}

# Night Raid on Stella Montis: 21 runs, 2026-11-03 05:00 UTC is the run
# 1793682000000 - 1793685600000
my @night = records_of('Night Raid', 'Stella Montis');
my $night = $EventTimer->from_grouped('Night Raid', 'Stella Montis', \@night);

# Close Scrutiny on Dam: one run, Wed 2026-11-04 13:00 - 14:00 UTC
my @scrutiny = records_of('Close Scrutiny', 'Dam');
my $scrutiny = $EventTimer->from_grouped('Close Scrutiny', 'Dam', \@scrutiny);

is(scalar @night, 21, 'fixture: 21 Night Raid runs on Stella Montis');
is(scalar @scrutiny, 1, 'fixture: one Close Scrutiny run');

subtest 'TimeSlot from_hashref reads startTime and endTime of a real record' => sub {
  my ($record) = @scrutiny;
  is($record->{startTime}, 1793797200000, 'fixture record: startTime in ms');

  my $slot = $TimeSlot->from_hashref($record);
  isa_ok($slot, $TimeSlot);
  is($slot->start->epoch, 1793797200, 'start: startTime / 1000');
  is($slot->end->epoch, 1793800800, 'end: endTime / 1000');
  is($slot->start->iso8601, '2026-11-04T13:00:00', 'start in UTC');
  is($slot->end->iso8601, '2026-11-04T14:00:00', 'end in UTC');
  is($slot->start->time_zone->name, 'UTC', 'time zone UTC');

  # Only startTime/endTime count, so swapped values show up
  my $other = $TimeSlot->from_hashref({ startTime => 1793653200000, endTime => 1793656800000 });
  is($other->start->iso8601, '2026-11-02T21:00:00', 'another record: start');
  is($other->end->iso8601, '2026-11-02T22:00:00', 'another record: end');
};

subtest 'TimeSlot from_epoch_ms' => sub {
  # 1767556800000 = 2026-01-04 20:00:00 UTC
  # 1767564000000 = 2026-01-04 22:00:00 UTC
  my $slot = $TimeSlot->from_epoch_ms(1767556800000, 1767564000000);

  isa_ok($slot, $TimeSlot);
  is($slot->start->year, 2026, 'start year');
  is($slot->start->hour, 20, 'start hour');
  is($slot->end->hour, 22, 'end hour');
};

subtest 'from_grouped maps the records of the fixture' => sub {
  is($night->name, 'Night Raid', 'name');
  is($night->map, 'Stella Montis', 'map');
  is($night->icon, $night[0]{icon}, 'icon from the first record');
  is($night->icon, 'https://static.metaforge.app/arc-raiders/custom/night.webp', 'icon value');
  ok(!defined $night->region, 'region undef: records of a single-region response carry none');
  is(scalar @{ $night->times }, 21, 'one TimeSlot per record');
  isa_ok($_, $TimeSlot) for $night->times->[0];

  my @starts = map { $_->start->epoch * 1000 } @{ $night->times };
  is_deeply(\@starts, [ sort { $a <=> $b } map { $_->{startTime} } @night ], 'slots start at the record times, ascending');
  ok(!grep({ $_->end->epoch - $_->start->epoch != 3600 } @{ $night->times }), 'every run lasts 60 minutes');

  is_deeply($night->_raw, { name => 'Night Raid', map => 'Stella Montis', events => \@night },
    '_raw keeps name, map and the untouched records');
};

subtest 'TimeSlot contains method' => sub {
  my $slot = $TimeSlot->from_hashref($scrutiny[0]);   # 13:00 - 14:00 on 4 Nov
  my $at = sub { DateTime->new(year => 2026, month => 11, day => 4, hour => $_[0], minute => $_[1], time_zone => 'UTC') };

  ok($slot->contains($at->(13, 30)), 'time inside slot');
  ok($slot->contains($at->(13, 0)), 'start is inside');
  ok(!$slot->contains($at->(14, 0)), 'end is outside');
  ok(!$slot->contains($at->(12, 59)), 'time before slot');
  ok(!$slot->contains($at->(15, 0)), 'time after slot');

  my $other_day = DateTime->new(year => 2026, month => 11, day => 3, hour => 13, minute => 30, time_zone => 'UTC');
  ok(!$slot->contains($other_day), 'same time of day on another day is outside');

  FrozenClock::at('2026-11-04T13:30:00', sub { ok($slot->contains, 'default: now, inside') });
  FrozenClock::at('2026-11-04T16:30:00', sub { ok(!$slot->contains, 'default: now, after') });
};

subtest 'is_active_now method' => sub {
  FrozenClock::at('2026-11-03T05:30:00', sub {
    ok($night->is_active_now, 'Night Raid | Stella Montis is active at Tue 05:30');
    ok(!$scrutiny->is_active_now, 'Close Scrutiny is not active, its run is a day later');
  });
  FrozenClock::at('2026-11-03T06:30:00', sub {
    ok(!$night->is_active_now, 'between two runs: inactive');
  });
  FrozenClock::at('2026-11-03T06:00:00', sub {
    ok(!$night->is_active_now, 'at the end of a run: inactive');
  });
  FrozenClock::at('2026-11-04T16:30:00', sub {
    ok(!$night->is_active_now, 'behind the window: inactive');
  });
};

subtest 'current_slot method' => sub {
  FrozenClock::at('2026-11-03T05:30:00', sub {
    my $slot = $night->current_slot;
    isa_ok($slot, $TimeSlot);
    is($slot->start->iso8601, '2026-11-03T05:00:00', 'the running slot starts 05:00');
    is($slot->end->iso8601, '2026-11-03T06:00:00', 'and ends 06:00');
    is($slot->minutes_until_end, 30, 'ends in 30 minutes');
    is($night->time_until_end, '30m', 'time_until_end');
    ok(!defined $scrutiny->current_slot, 'undef when nothing runs');
  });
};

subtest 'next_time method' => sub {
  FrozenClock::at('2026-11-03T05:30:00', sub {
    my $next = $night->next_time;
    isa_ok($next, $TimeSlot);
    is($next->start->iso8601, '2026-11-03T07:00:00', 'next run after the active one');
    is($night->minutes_until_start, 90, 'minutes_until_start');
    is($night->time_until_start, '1h 30m', 'time_until_start');

    is($scrutiny->next_time->start->iso8601, '2026-11-04T13:00:00', 'single run lies ahead');
  });
};

subtest 'next_time is undef when every run is over (no wrap-around)' => sub {
  # 16:30 on Wed 4 Nov is behind the window (last run ends 15:00)
  FrozenClock::at('2026-11-04T16:30:00', sub {
    ok(!defined $night->next_time, 'Night Raid | Stella Montis: no next run');
    ok(!defined $scrutiny->next_time, 'Close Scrutiny: no next run');
    ok(!defined $night->minutes_until_start, 'minutes_until_start undef');
    ok(!defined $night->time_until_start, 'time_until_start undef');
  });

  # Every group of the fixture
  my $api = WWW::MetaForge::ArcRaiders->new(use_cache => 0);
  my $timers = $api->_group_event_timers(\@records);
  is(scalar @$timers, 35, 'fixture: 35 groups');
  FrozenClock::at('2026-11-04T16:30:00', sub {
    is(scalar(grep { defined $_->next_time } @$timers), 0, 'no group has a next run');
    is(scalar(grep { $_->is_active_now } @$timers), 0, 'no group is active');
  });
};

subtest 'next_time with empty times' => sub {
  my $event = $EventTimer->from_grouped('Empty', 'Test', []);
  ok(!defined $event->next_time, 'next_time returns undef for empty times');
};

subtest 'defaults' => sub {
  my $event = $EventTimer->from_grouped('Minimal', 'Test', []);

  is(ref $event->times, 'ARRAY', 'times defaults to array');
  is(scalar @{$event->times}, 0, 'times is empty');
  ok(!defined $event->icon, 'icon defaults to undef');
  ok(!defined $event->region, 'region defaults to undef');
};

subtest 'region=all: records with a region group per name, map and region' => sub {
  # Synthetic list shaped like the region=all response (each record
  # carries a region); no fixture stands in for an API answer here.
  my $run = sub {
    my ($name, $map, $region, $start) = @_;
    return { name => $name, map => $map, icon => 'https://example.com/i.webp',
      startTime => $start, endTime => $start + 3600000, region => $region };
  };
  my $eu_1 = $run->('Night Raid', 'Dam', 'europe',        1793653200000);
  my $eu_2 = $run->('Night Raid', 'Dam', 'europe',        1793660400000);
  my $na_1 = $run->('Night Raid', 'Dam', 'north-america', 1793656800000);
  my $other = $run->('Hurricane', 'Dam', 'europe',        1793653200000);

  my $api = WWW::MetaForge::ArcRaiders->new(use_cache => 0);
  my $timers = $api->_group_event_timers([ $eu_1, $na_1, $eu_2, $other ]);

  is(scalar @$timers, 3, 'same name and map in two regions: two EventTimers (plus Hurricane)');
  my @night = grep { $_->name eq 'Night Raid' } @$timers;
  is(scalar @night, 2, 'two Night Raid timers');
  my %by_region = map { $_->region => $_ } @night;
  is_deeply([ sort keys %by_region ], [qw( europe north-america )], 'each with its own region');
  is(scalar @{ $by_region{europe}->times }, 2, 'europe: its two runs');
  is(scalar @{ $by_region{'north-america'}->times }, 1, 'north-america: its one run');
  is($by_region{'north-america'}->times->[0]->start->epoch, 1793656800, 'north-america run is the NA record');
  is_deeply($by_region{europe}->_raw->{events}, [ $eu_1, $eu_2 ], 'europe _raw: only its records');
  is((grep { $_->name eq 'Hurricane' } @$timers)[0]->region, 'europe', 'region of another event');

  # Without a region field (single-region response) records of
  # name+map stay one group
  my @plain = map { { %$_ } } $eu_1, $na_1;
  delete $_->{region} for @plain;
  my $plain = $api->_group_event_timers(\@plain);
  is(scalar @$plain, 1, 'no region field: one group');
  ok(!defined $plain->[0]->region, 'and no region');
};

done_testing;
