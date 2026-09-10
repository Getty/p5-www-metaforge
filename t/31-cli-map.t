#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/lib";

BEGIN {
  eval { require Capture::Tiny };
  if ($@) {
    plan skip_all => 'Capture::Tiny required for CLI tests';
  }
}
use Capture::Tiny qw(capture_stdout);

use_ok('WWW::MetaForge::ArcRaiders::CLI');
use_ok('WWW::MetaForge::ArcRaiders::CLI::Cmd::Map');

my $cache_dir = tempdir(CLEANUP => 1);

# The `map` command delegates to $app->api->map_data, which the ArcRaiders
# facade routes through a child GameMapData instance. That child builds its own
# LWP::UserAgent unless one is injected, so we hand the api a GameMapData backed
# by MockUA to keep the test offline.
sub mock_cli {
  require MockUA;
  my $ua = MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures");
  my $cli = WWW::MetaForge::ArcRaiders::CLI->new();
  $cli->{api} = WWW::MetaForge::ArcRaiders->new(
    ua            => $ua,
    cache_dir     => $cache_dir,
    use_cache     => 0,
    game_map_data => WWW::MetaForge::GameMapData->new(
      ua           => $ua,
      cache_dir    => $cache_dir,
      use_cache    => 0,
      marker_class => 'WWW::MetaForge::ArcRaiders::Result::MapMarker',
    ),
  );
  return $cli;
}

subtest 'map command lists markers' => sub {
  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Map->new();

  my $output = capture_stdout {
    $cmd->execute(['dam'], [$cli]);
  };

  like($output, qr/Markers for Dam/,   'shows map display name');
  like($output, qr{arc/tick},          'shows a category/subcategory type');
  like($output, qr/Red Lockers/,       'shows an instance name');
  like($output, qr/6 marker\(s\) found/, 'shows marker count');
};

subtest 'map command with type filter' => sub {
  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Map->new(type => 'containers');

  my $output = capture_stdout {
    $cmd->execute(['dam'], [$cli]);
  };

  like($output, qr/containers/,     'shows containers markers');
  unlike($output, qr{arc/tick},     'filters out non-matching types');
  like($output, qr/3 marker\(s\) found/, 'counts only filtered markers');
};

subtest 'map command without argument shows usage' => sub {
  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Map->new();

  my $output = capture_stdout {
    $cmd->execute([], [$cli]);
  };

  like($output, qr/Usage:/,          'shows usage message');
  like($output, qr/Available maps:/, 'lists available maps');
  like($output, qr/spaceport/,       'includes a known map id');
};

subtest 'map command JSON output' => sub {
  my $cli = mock_cli();
  $cli->{json} = 1;
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Map->new();

  my $output = capture_stdout {
    $cmd->execute(['dam'], [$cli]);
  };

  like($output, qr/^\[/,        'starts with [');
  like($output, qr/"category"/, 'has raw category field');

  require JSON::MaybeXS;
  my $data = eval { JSON::MaybeXS::decode_json($output) };
  ok(!$@, 'valid JSON') or diag("JSON error: $@");
  ok(ref $data eq 'ARRAY', 'is array');
  is(scalar @$data, 6, 'contains all markers');
};

done_testing;
