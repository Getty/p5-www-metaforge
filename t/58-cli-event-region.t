#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use Capture::Tiny qw(capture_stdout);
use File::Temp qw(tempdir);
use JSON::MaybeXS;
use MockUA;
use FrozenClock;
use WWW::MetaForge::ArcRaiders;
use WWW::MetaForge::ArcRaiders::CLI;
use WWW::MetaForge::ArcRaiders::CLI::Cmd::Event;
use WWW::MetaForge::ArcRaiders::CLI::Cmd::Events;

# k36, CLI part: events and event take --region; without it no region goes to
# the API; event lists running and upcoming runs only.
#
# t/fixtures/events-schedule.json is the europe response of Tue 3 Nov 2026
# (window Mon 21:00 - Wed 15:00 UTC); t/fixtures/events-schedule-region-all.json
# is the byte-faithful region=all response (5 regions, 830 records, every record
# carries "region"), fetched 1.5 h later. MockUA serves the latter for region=all.
# The clock is frozen inside the window.

my $cache_dir = tempdir(CLEANUP => 1);

sub mock_cli {
  my $cli = WWW::MetaForge::ArcRaiders::CLI->new();
  $cli->{mock_ua} = MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures");
  $cli->{api} = WWW::MetaForge::ArcRaiders->new(
    ua        => $cli->{mock_ua},
    cache_dir => $cache_dir,
    use_cache => 0,
  );
  return $cli;
}

# returns ( stdout, request URI of the schedule )
sub run_cmd {
  my ($class, $when, $args, %opt) = @_;
  my $json = delete $opt{json};
  my $cli  = mock_cli();
  $cli->{json} = 1 if $json;
  my $cmd = $class->new(%opt);
  my $out = '';
  FrozenClock::at($when, sub { $out = capture_stdout { $cmd->execute($args, [$cli]) } });
  my @sched = grep { m{/events-schedule} } $cli->{mock_ua}->requests;
  return ($out, @sched);
}

my $EVENT  = 'WWW::MetaForge::ArcRaiders::CLI::Cmd::Event';
my $EVENTS = 'WWW::MetaForge::ArcRaiders::CLI::Cmd::Events';
my $EU     = '2026-11-03T05:30:00';
my $ALL    = '2026-11-03T08:30:00';

subtest 'events --region goes to the API' => sub {
  my ($out, @req) = run_cmd($EVENTS, $EU, [], region => 'north-america');
  is(scalar @req, 1, 'one schedule request');
  like($req[0], qr/[?&]region=north-america(?:&|$)/, 'query has region=north-america');
};

subtest 'event --region goes to the API' => sub {
  my ($out, @req) = run_cmd($EVENT, $EU, ['Night Raid'], region => 'east-asia', map => 'dam');
  is(scalar @req, 1, 'one schedule request');
  like($req[0], qr/[?&]region=east-asia(?:&|$)/, 'query has region=east-asia');
};

subtest 'without --region no region is sent' => sub {
  my (undef, @req) = run_cmd($EVENTS, $EU, []);
  unlike($req[0], qr/region/, 'events: no region in the URL');
  (undef, @req) = run_cmd($EVENT, $EU, ['Close Scrutiny']);
  unlike($req[0], qr/region/, 'event: no region in the URL');
};

subtest 'without --region=all there is no region column or label' => sub {
  my ($events) = run_cmd($EVENTS, $EU, []);
  unlike($events, qr/europe|north-america|oceania|east-asia|brazil/, 'events: no region anywhere');
  like($events, qr/^Night Raid\s+Dam\s+/m, 'events: still lists Night Raid on Dam');
  my ($event) = run_cmd($EVENT, $EU, ['Close Scrutiny']);
  unlike($event, qr/Region:/, 'event: no Region field');
  my ($other) = run_cmd($EVENTS, $EU, [], region => 'north-america');
  unlike($other, qr/north-america/, 'a single region is not echoed as a column either');
};

subtest 'schedule of a running event' => sub {
  # Harvester | Dam has one run in the europe window: Tue 16:00 - 17:00
  my ($before) = run_cmd($EVENT, '2026-11-03T16:59:59', ['Harvester'], map => 'dam');
  like($before, qr/^Schedule \(UTC\):\n  Tue 03 Nov 16:00 - 17:00\n/m, '16:59:59: the run is still listed');
  unlike($before, qr/No current or upcoming/, '16:59:59: no empty-schedule note');
};

subtest 'schedule with every run over' => sub {
  for my $when ('2026-11-03T18:00:00', '2026-11-03T17:00:00') {
    my ($out) = run_cmd($EVENT, $when, ['Harvester'], map => 'dam');
    like($out, qr/Schedule \(UTC\):\n  No current or upcoming runs in the schedule window\.\n\z/,
      "$when: the note ends the output");
    unlike($out, qr/^  \w{3} \d\d \w{3} \d\d:\d\d - /m, "$when: no run line");
  }
};

subtest '--json keeps every run' => sub {
  my ($out) = run_cmd($EVENT, $EU, ['Night Raid'], map => 'stella-montis', json => 1);
  my $data = decode_json($out);
  is(scalar @{ $data->{events} }, 21, 'all 21 runs of the window, past ones included');
  is($data->{events}[0]{startTime}, 1793660400000, 'the first record is Mon 2 Nov 23:00');
};

subtest 'europe hint stays as it was' => sub {
  my ($out) = run_cmd($EVENT, $EU, ['Night Raid']);
  like($out, qr/^\nUse --map to specify: metaforge-arcraiders event "Night Raid" --map <map>\n\z/m,
    'the hint is verbatim');
  like($out, qr/^  Night Raid \(Dam\)$/m, 'list entries have no region');
};

subtest 'events --region all: a region column' => sub {
  my ($out, @req) = run_cmd($EVENTS, $ALL, [], region => 'all');
  like($req[0], qr/[?&]region=all(?:&|$)/, 'query has region=all');
  like($out, qr/^Night Raid\s+Dam\s+north-america\s+/m, 'Night Raid | Dam | north-america');
  like($out, qr/^Night Raid\s+Dam\s+oceania\s+/m, 'Night Raid | Dam | oceania');
  for my $region (qw( europe north-america oceania east-asia brazil )) {
    like($out, qr/^\S.*\s\Q$region\E\s/m, "region $region shows up");
  }
  like($out, qr/^\n\d+ event\(s\) found\.\n\z/m, 'count line');
  my ($count) = $out =~ /^(\d+) event\(s\) found/m;
  is(scalar(() = $out =~ /^\S.*\s(?:europe|north-america|oceania|east-asia|brazil)\s/mg), $count,
    'every entry has a region');
};

subtest 'event --region all: matches name the region' => sub {
  my ($out) = run_cmd($EVENT, $ALL, ['Night Raid'], region => 'all');
  like($out, qr/^Multiple events match 'Night Raid':$/m, 'multiple matches');
  like($out, qr/^  Night Raid \(Dam, north-america\)$/m, 'Dam, north-america');
  like($out, qr/^  Night Raid \(Stella Montis, brazil\)$/m, 'Stella Montis, brazil');
  like($out, qr/^\nUse --map and --region to specify: metaforge-arcraiders event "Night Raid" --map <map> --region <region>\n\z/m,
    'maps and regions differ: both options');

  ($out) = run_cmd($EVENT, $ALL, ['Night Raid'], region => 'all', map => 'dam');
  like($out, qr/^  Night Raid \(Dam, europe\)$/m, 'with --map dam: Dam, europe');
  unlike($out, qr/Stella Montis|Spaceport/, 'only Dam is listed');
  like($out, qr/^\nUse --region to specify: metaforge-arcraiders event "Night Raid" --map "dam" --region <region>\n\z/m,
    'only regions differ: --region, the given --map is kept');
};

subtest 'detail view names the region' => sub {
  # every event+map exists in all 5 regions, so `event` never reaches a single
  # match with region=all; take one region's timer and print it directly
  my $cli    = mock_cli();
  my $timers = $cli->api->event_timers(region => 'all');
  my ($timer) = grep { $_->name eq 'Night Raid' && $_->map eq 'Dam' && $_->region eq 'north-america' } @$timers;
  ok($timer, 'Night Raid | Dam | north-america timer from the region=all fixture');
  my $out = '';
  FrozenClock::at($ALL, sub {
    $out = capture_stdout { WWW::MetaForge::ArcRaiders::CLI::Cmd::Event::_print_event_details($timer) };
  });
  like($out, qr/^Map:\s+Dam$/m, 'map');
  like($out, qr/^Region:\s+north-america$/m, 'Region: north-america');
  like($out, qr/^Schedule \(UTC\):\n  Wed 04 Nov 03:00 - 04:00\n\z/m, 'its single run (Wed 03:00), nothing else');
};

done_testing;
