#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use JSON::MaybeXS qw( decode_json );
use URI;
use lib "$FindBin::Bin/lib";

BEGIN {
  eval { require Capture::Tiny };
  if ($@) {
    plan skip_all => 'Capture::Tiny required for CLI tests';
  }
}
use Capture::Tiny qw(capture_stdout);
use RecordingUA;

use_ok('WWW::MetaForge::ArcRaiders::CLI');
use_ok('WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest');
use_ok('WWW::MetaForge::ArcRaiders::CLI::Cmd::Arc');
use_ok('WWW::MetaForge::ArcRaiders::CLI::Cmd::Arcs');

my $cache_dir = tempdir(CLEANUP => 1);

# filter_by_id: the live API answers ?id=... with just that record; the
# fixtures are page 1 of the listing, so the test UA applies the filter.
sub mock_cli {
  my $ua  = RecordingUA->new(fixtures_dir => "$FindBin::Bin/fixtures", filter_by_id => 1);
  my $cli = WWW::MetaForge::ArcRaiders::CLI->new();
  $cli->{api} = WWW::MetaForge::ArcRaiders->new(
    ua        => $ua,
    cache_dir => $cache_dir,
    use_cache => 0,
  );
  return ($cli, $ua);
}

sub query_of { return { URI->new($_[0])->query_form } }

subtest 'quest - required items are printed by quantity and name' => sub {
  my ($cli, $ua) = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest->new();

  my $output = capture_stdout { $cmd->execute(['after-rain-comes'], [$cli]) };

  unlike($output, qr/HASH\(0x/, 'no stringified hashrefs (regression)');
  like($output, qr/^After Rain Comes$/m,        'name');
  like($output, qr/^ID:\s+after-rain-comes$/m,  'id');
  like($output, qr/^Required Items:\n  5x Wires\n  2x Battery\n/m, 'required items: quantity and name');
  like($output, qr/^Granted Items:\n  1x Zipline\n/m, 'granted items');
  is_deeply(query_of(($ua->seen_uris)[0])->{id}, 'after-rain-comes', 'it asked for the quest by id');
};

subtest 'quest - trader, prerequisites, description, rewards' => sub {
  my ($cli) = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest->new();

  my $output = capture_stdout { $cmd->execute(['after-rain-comes'], [$cli]) };

  like($output, qr/^Trader:\s+Celeste$/m,              'trader');
  like($output, qr/^Requires:\s+Eyes in the Sky$/m,    'prerequisite from the manifest');
  like($output, qr/^Description:\n  I know, I know!/m, 'description');
  like($output, qr/^Rewards:\n  2500 XP\n  5x Blue Light Stick\n  3x Antiseptic\n  5x Durable Cloth\n/m,
    'rewards: additional (XP) first, then the items');

  my ($description) = $output =~ /^Description:\n(.*?)\n\nObjectives:/ms;
  my @lines = split /\n/, $description;
  cmp_ok(scalar @lines, '>', 1, 'the description wraps over several lines');
  like($lines[-1], qr/\S+\s+\S+/, 'the last line holds more than one word (regression: last word alone on a line)');
  unlike($description, qr/\r/, 'no carriage returns from the CRLF text');
  like($description, qr/up there, OK\?$/, 'the text ends where the API text ends');

  my $several = capture_stdout { $cmd->execute(['back-on-top'], [$cli]) };
  like($several, qr/^Requires:\s+The Major.{1,3}s Footlocker, Eyes in the Sky, Celeste.{1,3}s Journals$/m,
    'several prerequisites, in manifest order');
};

subtest 'quest - cosmetic rewards' => sub {
  my ($cli) = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest->new();

  my $output = capture_stdout { $cmd->execute(['a-symbol-of-unification'], [$cli]) };

  like($output, qr/^  Aviator Color: Dusted Cream$/m,    'cosmetic option with group, setting, name');
  like($output, qr/^  Aviator Headgear: On$/m,           'second cosmetic option');
  like($output, qr/^  5000 XP$/m,                        'currency reward');
  like($output, qr/^  1x Aviator \(Outfit\)$/m,          'item reward');
  unlike($output, qr/^Required Items:/m,                 'no required items section for a quest without');
};

subtest 'quest - JSON output and unknown quest' => sub {
  my ($cli) = mock_cli();
  $cli->{json} = 1;
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest->new();

  my $output = capture_stdout { $cmd->execute(['after-rain-comes'], [$cli]) };
  my $data = decode_json($output);
  is($data->{id}, 'after-rain-comes', 'raw quest as JSON');
  is(scalar @{ $data->{required_items} }, 2, 'raw required_items');
  is($data->{manifest}{prerequisites}[0]{quest_id}, 'eyes-in-the-sky', 'raw manifest');

  $cli->{json} = 0;
  $output = capture_stdout { $cmd->execute(['no-such-quest'], [$cli]) };
  like($output, qr/Quest 'no-such-quest' not found/, 'unknown quest is reported');
};

subtest 'quest - by name, which is not the id (the id lookup answers 404)' => sub {
  my ($cli, $ua) = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest->new();

  my $output;
  my $error = do { local $@; eval { $output = capture_stdout { $cmd->execute(['A Bad Feeling'], [$cli]) }; 1 } ? '' : $@ };
  is($error, '', 'no exception');
  unlike($output, qr/API request failed|not found/, 'neither an error nor "not found"');
  like($output, qr/^A Bad Feeling$/m,       'name');
  like($output, qr/^ID:\s+a-bad-feeling$/m, 'the quest with id a-bad-feeling');
  is(query_of(($ua->seen_uris)[0])->{id}, 'A Bad Feeling', 'it tried the argument as id first');
};

subtest 'quest - a known id costs exactly one request' => sub {
  my ($cli, $ua) = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest->new();

  my $output = capture_stdout { $cmd->execute(['celestes-journals'], [$cli]) };
  like($output, qr/^ID:\s+celestes-journals$/m, 'found');
  my @uris = $ua->seen_uris;
  is(scalar @uris, 1, 'one request, no quests_all');
  is(query_of($uris[0])->{id}, 'celestes-journals', 'by id');
};

subtest 'quest - an unknown quest is reported, not a die' => sub {
  my ($cli) = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest->new();

  my $output;
  my $error = do { local $@; eval { $output = capture_stdout { $cmd->execute(['no-such-quest'], [$cli]) }; 1 } ? '' : $@ };
  is($error, '', 'no exception (the id lookup answers 404 live)');
  like($output, qr/^Quest 'no-such-quest' not found\.$/m, 'reported');
};

subtest 'arcs --loot sends includeLoot=true' => sub {
  my ($cli, $ua) = mock_cli();
  $cli->{json} = 1;
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Arcs->new(loot => 1);

  my $output = capture_stdout { $cmd->execute([], [$cli]) };

  my $query = query_of(($ua->seen_uris)[0]);
  is($query->{includeLoot}, 'true', 'includeLoot=true (not 1, which the API ignores)');
  unlike(($ua->seen_uris)[0], qr/includeLoot=1\b/, 'the query does not carry includeLoot=1');

  my $arcs = decode_json($output);
  is(scalar @$arcs, 26, 'all arcs');
  my ($rollbot) = grep { $_->{id} eq 'rollbot' } @$arcs;
  is(scalar @{ $rollbot->{loot} }, 14, 'with the flag, the arcs carry their loot');
};

subtest 'arcs without --loot' => sub {
  my ($cli, $ua) = mock_cli();
  $cli->{json} = 1;
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Arcs->new();

  my $output = capture_stdout { $cmd->execute([], [$cli]) };

  unlike(($ua->seen_uris)[0], qr/includeLoot/, 'no includeLoot in the query');
  my ($rollbot) = grep { $_->{id} eq 'rollbot' } @{ decode_json($output) };
  ok(!exists $rollbot->{loot}, 'without the flag the API sends no loot key');

  $cli->{json} = 0;
  my $text = capture_stdout { $cmd->execute([], [$cli]) };
  like($text, qr/^ARC Surveyor\s+\[rollbot\]$/m, 'text list: name and id');
  like($text, qr/26 ARC\(s\) found\./, 'count');
};

subtest 'arc - flying and loot rarity' => sub {
  my ($cli, $ua) = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Arc->new();

  my $output = capture_stdout { $cmd->execute(['rollbot'], [$cli]) };
  my $query = query_of(($ua->seen_uris)[0]);
  is($query->{id}, 'rollbot', 'asked by id');
  is($query->{includeLoot}, 'true', 'with includeLoot=true');
  like($output, qr/^ARC Surveyor$/m,                'name');
  like($output, qr/^Flying:\s+no$/m,                'Flying: no (can_fly false)');
  like($output, qr/^  ARC Alloy\s+Uncommon$/m,      'loot drop with its rarity');
  like($output, qr/^  Vita Spray Blueprint\s+Legendary$/m, 'another drop with its rarity');

  $output = capture_stdout { $cmd->execute(['firefly'], [$cli]) };
  like($output, qr/^Flying:\s+yes$/m, 'Flying: yes (can_fly true)');

  $output = capture_stdout { $cmd->execute(['frigate'], [$cli]) };
  like($output, qr/^ARC Frigate$/m, 'frigate found');
  unlike($output, qr/^Flying:/m, 'no Flying line without data');
  unlike($output, qr/Loot Drops/, 'no loot section without loot');
};

done_testing;
