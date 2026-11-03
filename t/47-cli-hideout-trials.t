#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use JSON::MaybeXS qw( decode_json );
use Path::Tiny;
use lib "$FindBin::Bin/lib";

BEGIN {
  eval { require Capture::Tiny };
  if ($@) {
    plan skip_all => 'Capture::Tiny required for CLI tests';
  }
}
use Capture::Tiny qw(capture_stdout);
use MockUA;

use_ok('WWW::MetaForge::ArcRaiders::CLI');
use_ok('WWW::MetaForge::ArcRaiders::CLI::Cmd::Hideout');
use_ok('WWW::MetaForge::ArcRaiders::CLI::Cmd::Trials');

my $hideout_raw = decode_json(path("$FindBin::Bin/fixtures/hideout.json")->slurp_raw);
my $trials_raw  = decode_json(path("$FindBin::Bin/fixtures/weekly-trials.json")->slurp_raw);

# Every test gets its own cli and its own temp cache dir; the cache is off
sub mock_cli {
  my $cli = WWW::MetaForge::ArcRaiders::CLI->new();
  $cli->{api} = WWW::MetaForge::ArcRaiders->new(
    ua        => MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures"),
    cache_dir => tempdir(CLEANUP => 1),
    use_cache => 0,
  );
  return $cli;
}

# The Trials command prints "(in 4h 33m)" after a time, which depends on the
# clock (the command reads time(), not DateTime->now); only the absolute UTC
# time is asserted.
sub run_cmd {
  my ($class, $args, %opt) = @_;
  my $cli = mock_cli();
  $cli->{json} = 1 if delete $opt{json};
  my $argv = delete $opt{argv} // [];
  my $cmd;
  { local @ARGV = @$argv; $cmd = $class->new_with_options(%opt); }
  return capture_stdout { $cmd->execute($args, [$cli]) };
}

my $Hideout = 'WWW::MetaForge::ArcRaiders::CLI::Cmd::Hideout';
my $Trials  = 'WWW::MetaForge::ArcRaiders::CLI::Cmd::Trials';

subtest 'hideout - list' => sub {
  my $output = run_cmd($Hideout, []);

  like($output, qr/^Scrappy\s+\[scrappy\]\s+6 levels$/m, 'Scrappy');
  like($output, qr/^Gunsmith\s+\[weapon-bench\]\s+4 levels$/m, 'Gunsmith with id and levels');
  like($output, qr/^Outpost\s+\[outpost\]\s+4 levels$/m, 'Outpost');
  is(scalar(() = $output =~ /^\S.*\[[a-z-]+\]\s+\d+ levels$/mg), 9, 'nine station lines');
  like($output, qr/^9 station\(s\) found\.$/m, 'count');
  unlike($output, qr/HASH\(0x/, 'no stringified references');
};

subtest 'hideout - detail by id and by name, any case' => sub {
  my $by_id = run_cmd($Hideout, ['weapon-bench']);
  like($by_id, qr/^Gunsmith$/m, 'title');
  like($by_id, qr/^ID:\s+weapon-bench$/m, 'id');
  like($by_id, qr/^Max Level:\s+4$/m, 'max level');
  like($by_id, qr/^Level 1$/m, 'level 1');
  like($by_id, qr/^  Unlock:\s+3 rounds-played$/m, 'unlock requirement');
  like($by_id, qr/^  Requires:\s+20x metal-parts, 30x rubber-parts-recipe$/m, 'level 1 items');
  like($by_id, qr/^  Requires:\s+3x rusted-tools, 5x mechanical-components, 8x wasp-driver$/m, 'level 2 items');
  like($by_id, qr/^Level 4$/m, 'level 4');
  unlike($by_id, qr/^Level 5$/m, 'no level 5');

  is(run_cmd($Hideout, ['gunsmith']), $by_id, 'by name, lower case');
  is(run_cmd($Hideout, ['WEAPON-BENCH']), $by_id, 'by id, upper case');
  is(run_cmd($Hideout, ['GUNSMITH']), $by_id, 'by name, upper case');

  my $scrappy = run_cmd($Hideout, ['scrappy']);
  like($scrappy, qr/^Level 1\n  \(nothing required\)$/m, 'Scrappy level 1 requires nothing');
  like($scrappy, qr/^  Requires:\s+1x dog-collar$/m, 'Scrappy level 2');
};

subtest 'hideout - unknown station' => sub {
  my $output = run_cmd($Hideout, ['nope']);
  like($output, qr/^Hideout station 'nope' not found\.$/m, 'not found');
  like($output, qr/^  Gunsmith\s+\[weapon-bench\]$/m, 'lists the stations');
  unlike($output, qr/^Level \d/m, 'no detail view');
};

subtest 'hideout - JSON output' => sub {
  my $list = decode_json(run_cmd($Hideout, [], json => 1));
  is(ref $list, 'ARRAY', 'list: array');
  is_deeply($list, $hideout_raw, 'list: the raw response');

  my $station = decode_json(run_cmd($Hideout, ['scrappy'], json => 1));
  is(ref $station, 'HASH', 'detail: object');
  is_deeply($station, $hideout_raw->[0], 'detail: the raw station');
  is_deeply([ sort { $a <=> $b } keys %{ $station->{levels} } ], [1 .. 6], 'with all six levels');
  is_deeply($station->{levels}{1}, {}, 'level 1 is {}');
};

subtest 'trials - default view: active and upcoming' => sub {
  my $output = run_cmd($Trials, []);

  like($output, qr/^Active, until 2026-11-03 10:00 UTC/m, 'active window end, UTC');
  like($output, qr/^Upcoming, from 2026-11-03 12:00 UTC/m, 'next window start, UTC');

  my ($active, $upcoming) = split /^\nUpcoming/m, $output;
  for my $name ('Damage ARC enemies using a Deadline', 'Damage ARC using a Blaze Grenade', 'Search Backpacks') {
    like($active, qr/^  \Q$name\E\s*$/m, "active: $name");
  }
  like($active, qr/^  Search Husks\s+Pendola Pass$/m, 'active: Search Husks on Pendola Pass');
  like($upcoming, qr/^  Damage Comets\s*$/m, 'upcoming: Damage Comets');
  like($upcoming, qr/^  Search ARC Couriers\s+Pendola Pass$/m, 'upcoming: Search ARC Couriers on Pendola Pass');
  like($upcoming, qr/^  Search Husks\s*$/m, 'upcoming: Search Husks without a map');
  is(scalar(() = $active =~ /^  \S/mg), 5, 'five active lines');
  is(scalar(() = $upcoming =~ /^  \S/mg), 5, 'five upcoming lines');
  unlike($output, qr/Damage any ARC enemies/, 'no catalog entry');
};

subtest 'trials - catalog, as --catalog and as -c' => sub {
  my $long  = run_cmd($Trials, [], argv => ['--catalog']);
  my $short = run_cmd($Trials, [], argv => ['-c']);

  is($short, $long, '-c is --catalog');
  like($long, qr/^Damage any ARC enemies\s+\[tSpkG3vp\]$/m, 'a catalog trial with its trial id');
  like($long, qr/^126 catalog trial\(s\) found\.$/m, 'count');
  is(scalar(() = $long =~ /^\S.*\[[0-9A-Za-z]{8}\]$/mg), 126, '126 catalog lines');
  unlike($long, qr/^Active, until|^Upcoming, from/m, 'no window lines');
  unlike($long, qr/\[XUirqWfM\]/, 'a scheduled trial (Damage Comets, XUirqWfM) is not in the catalog');
};

subtest 'trials - JSON output' => sub {
  my $data = decode_json(run_cmd($Trials, [], json => 1));
  is_deeply([ sort keys %$data ], [qw( activeWindowEnd data nextWindowStart )], 'envelope keys');
  is($data->{activeWindowEnd}, 1793700000, 'activeWindowEnd');
  is($data->{nextWindowStart}, 1793707200, 'nextWindowStart');
  is(scalar @{ $data->{data} }, 10, 'default: the 10 scheduled trials');
  is_deeply($data->{data}, [ (grep { $_->{is_active} } @{ $trials_raw->{data} }), (grep { $_->{upcoming} } @{ $trials_raw->{data} }) ], 'the raw records of the scheduled trials, active first');

  my $catalog = decode_json(run_cmd($Trials, [], json => 1, argv => ['-c']));
  is(scalar @{ $catalog->{data} }, 126, '--catalog: the 126 catalog trials');
  is_deeply([ sort keys %$catalog ], [qw( activeWindowEnd data nextWindowStart )], '--catalog: envelope keys');
};

subtest 'help names hideout and trials' => sub {
  my $cli = mock_cli();
  my $output = capture_stdout { $cli->execute([], [$cli]) };
  like($output, qr/^\s+hideout\s+\S/m, 'hideout');
  like($output, qr/^\s+trials\s+\S/m, 'trials');
};

done_testing;
