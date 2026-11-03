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

# The `map` command delegates to $app->api->map_data. The ArcRaiders facade
# hands its own ua to the child GameMapData, so injecting MockUA is enough.
sub mock_cli {
  require MockUA;
  my $cli = WWW::MetaForge::ArcRaiders::CLI->new();
  $cli->{api} = WWW::MetaForge::ArcRaiders->new(
    ua        => MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures"),
    cache_dir => $cache_dir,
    use_cache => 0,
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
  like($output, qr{arc/bastion},       'shows a category/subcategory type');
  like($output, qr/Generator/,         'shows an instance name');
  like($output, qr/Industrial Crate/,  'shows the instance name of a MetaForge marker');
  like($output, qr/8 marker\(s\) found/, 'shows marker count');
  my @community = $output =~ /^(.*\[community\])$/mg;
  is(scalar @community, 6, 'six of the eight markers are flagged [community]');
  like($output, qr{^\s+containers/base_container\s+\(3657\.3, 2040\.55\)\s+Generator\s+\[community\]$}m,
    'the community Generator line: type, coordinates (x = lng, y = lat), name, flag');
  like($output, qr{^\s+containers/base_container\s+\(3664\.23, 2011\.99\)\s+Industrial Crate$}m,
    'the MetaForge Industrial Crate line has no [community] flag') or diag($output);
  unlike($output, qr/Industrial Crate.*\[community\]/, 'Industrial Crate is not flagged');
};

subtest 'map command with type filter' => sub {
  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Map->new(type => 'containers');

  my $output = capture_stdout {
    $cmd->execute(['dam'], [$cli]);
  };

  like($output, qr/containers/,     'shows containers markers');
  unlike($output, qr{arc/bastion},  'filters out non-matching types');
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
  like($output, qr/^\s+pendola-pass\s+Pendola Pass$/m, 'lists pendola-pass with its display name');
};

subtest 'map command lists pendola-pass markers' => sub {
  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Map->new();

  my $output = capture_stdout {
    $cmd->execute(['pendola-pass'], [$cli]);
  };

  like($output, qr/Markers for Pendola Pass/, 'shows map display name');
  like($output, qr{arc/sentinel},             'shows a category/subcategory type');
  like($output, qr/Server Rack/,              'shows an instance name');
  like($output, qr/6 marker\(s\) found/,      'shows marker count');
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
  is(scalar @$data, 8, 'contains all markers');
  is_deeply([ (map { $_->{id} } @$data)[0, 3] ], [ '00e5f6e7-d55b-97b1-385b-34e4741fa2e3', '1c08e459-3da5-d1f7-e1bf-10e442fa6fc4' ], 'records are in API order');
  is($data->[0]{lootAreas}, 'Industrial, Security', 'raw record keeps lootAreas');
  is($data->[3]{routeID}, '10e6170b3c30915aa28be9c1', 'raw record keeps routeID');
};

done_testing;
