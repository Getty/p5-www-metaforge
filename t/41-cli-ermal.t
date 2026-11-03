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
use RecordingUA;

use_ok('WWW::MetaForge::ArcRaiders::CLI');
use_ok('WWW::MetaForge::ArcRaiders::CLI::Cmd::Ermal');

my $cache_dir = tempdir(CLEANUP => 1);
my $ermal_section = decode_json( path("$FindBin::Bin/fixtures/traders.json")->slurp_raw )->{ermal};

sub mock_cli {
  my (%ua_args) = @_;
  my $ua  = RecordingUA->new(fixtures_dir => "$FindBin::Bin/fixtures", %ua_args);
  my $cli = WWW::MetaForge::ArcRaiders::CLI->new();
  $cli->{api} = WWW::MetaForge::ArcRaiders->new(
    ua        => $ua,
    cache_dir => $cache_dir,
    use_cache => 0,
  );
  return ($cli, $ua);
}

subtest 'ermal command - text output' => sub {
  my ($cli, $ua) = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Ermal->new();

  my $output = capture_stdout { $cmd->execute([], [$cli]) };

  like($output, qr/^Ermal$/m,                                   'title');
  like($output, qr/^Synced:\s+2026-10-27T12:59:24\.839\+00:00$/m, 'synced_at');
  like($output, qr/^Offers \(10\):$/m,                          'offer count');
  like($output, qr/^Permanent Services \(2\):$/m,               'service count');

  like($output, qr/^  2\.3 Backpack Attachment: Cauldron$/m,    'offer title');
  like($output, qr/^\s+Item:\s+Cauldron \(Backpack Attachment\) \[Cosmetic\]$/m, 'offer item with type');
  like($output, qr/^\s+Cost:\s+50000 coins$/m,                  'offer cost');
  like($output, qr/^\s+Runs:\s+2026-10-27T13:00:00\+00:00 - 2026-11-03T13:00:00\+00:00$/m, 'offer window');
  like($output, qr/^\s+Accepts:\s+1x Bronze Statuette, 1x Queen Reactor$/m, 'accepted items with amounts');
  like($output, qr/Any Firearm, 1x Wasp Driver/,                'category entry without amount');

  like($output, qr/^  Raider Tokens x25$/m,                    'offer without item is listed');
  like($output, qr/^  Expedition Vault$/m,                      'service name');
  like($output, qr/^\s+Cost:\s+200000 coins$/m,                 'service cost');
  like($output, qr/Safely stores items between expeditions/,    'service description');
  unlike($output, qr/HASH\(0x/,                                 'no stringified references');

  is(scalar($ua->seen), 1, 'one request');
};

subtest 'ermal command - JSON output' => sub {
  my ($cli) = mock_cli();
  $cli->{json} = 1;
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Ermal->new();

  my $output = capture_stdout { $cmd->execute([], [$cli]) };

  my $data = eval { decode_json($output) };
  ok(!$@, 'valid JSON') or diag("JSON error: $@");
  is(ref $data, 'HASH', 'is an object');
  is_deeply($data, $ermal_section, 'the raw ermal section of the response');
  is($data->{synced_at}, '2026-10-27T12:59:24.839+00:00', 'synced_at');
  is(scalar @{ $data->{offers} }, 10, 'offers');
};

subtest 'ermal command - no ermal section' => sub {
  my ($cli) = mock_cli(drop_sections => ['ermal']);
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Ermal->new();

  my $output = capture_stdout { $cmd->execute([], [$cli]) };

  like($output, qr/No Ermal data in the traders response/, 'says so');
  unlike($output, qr/Offers/, 'prints no sections');
};

done_testing;
