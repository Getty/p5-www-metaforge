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
use_ok('WWW::MetaForge::ArcRaiders::CLI::Cmd::Trader');

my $cache_dir = tempdir(CLEANUP => 1);

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

subtest 'trader command - single trader lookup' => sub {
  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Trader->new();

  my $output = capture_stdout {
    $cmd->execute(['Apollo'], [$cli]);
  };

  like($output, qr/Apollo/,          'shows trader name');
  like($output, qr/Inventory: \d+ item\(s\)/, 'shows inventory count');
};

subtest 'trader command - case insensitive match' => sub {
  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Trader->new();

  my $output = capture_stdout {
    $cmd->execute(['apollo'], [$cli]);
  };

  like($output, qr/Apollo/, 'matches trader name case-insensitively');
};

subtest 'trader command - unknown trader' => sub {
  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Trader->new();

  my $output = capture_stdout {
    $cmd->execute(['Nonexistent'], [$cli]);
  };

  like($output, qr/not found/i,       'reports trader not found');
  like($output, qr/Available traders:/, 'lists available traders');
};

subtest 'trader command - no argument shows usage' => sub {
  my $cli = mock_cli();
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Trader->new();

  my $output = capture_stdout {
    $cmd->execute([], [$cli]);
  };

  like($output, qr/Usage:/i, 'shows usage message');
};

subtest 'trader command - JSON output' => sub {
  my $cli = mock_cli();
  $cli->{json} = 1;
  my $cmd = WWW::MetaForge::ArcRaiders::CLI::Cmd::Trader->new();

  my $output = capture_stdout {
    $cmd->execute(['Apollo'], [$cli]);
  };

  like($output, qr/^\{/,      'starts with {');
  like($output, qr/"name"/,   'has name field');

  require JSON::MaybeXS;
  my $data = eval { JSON::MaybeXS::decode_json($output) };
  ok(!$@, 'valid JSON') or diag("JSON error: $@");
  is($data->{name}, 'Apollo', 'JSON carries the trader name');
};

done_testing;
