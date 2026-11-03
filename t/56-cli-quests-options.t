#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
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
use_ok('WWW::MetaForge::ArcRaiders::CLI::Cmd::Quests');

# "quests" has no --type option. Quests carry no type live and the API
# ignores the parameter, so the CLI must neither offer the option nor send
# type= in the request.

my $class     = 'WWW::MetaForge::ArcRaiders::CLI::Cmd::Quests';
my $cache_dir = tempdir(CLEANUP => 1);

sub mock_cli {
  my $ua  = RecordingUA->new(fixtures_dir => "$FindBin::Bin/fixtures");
  my $cli = WWW::MetaForge::ArcRaiders::CLI->new();
  $cli->{api} = WWW::MetaForge::ArcRaiders->new(
    ua        => $ua,
    cache_dir => $cache_dir,
    use_cache => 0,
  );
  return ($cli, $ua);
}

sub query_of { return { URI->new($_[0])->query_form } }

subtest 'quests declares only --all and --page' => sub {
  my %options = $class->_options_data;
  is_deeply([ sort keys %options ], [qw( all page )], 'the option set is all and page');
  ok(!$class->can('type'), 'no type accessor');
};

subtest 'quests never sends type= in the request' => sub {
  my ($cli, $ua) = mock_cli();
  # a type handed to the command (as --type x would set it) must not reach the API
  my $cmd = $class->new( type => 'x' );

  my $output = capture_stdout { $cmd->execute([], [$cli]) };

  my @uris = $ua->seen_uris;
  is(scalar @uris, 1, 'one request');
  like($uris[0], qr{/api/arc-raiders/quests\b}, 'it is the quests endpoint');
  ok(!exists query_of($uris[0])->{type}, 'no type parameter in the query')
    or diag $uris[0];
  unlike($uris[0], qr/type=/, 'no type= anywhere in the URL');
  like($output, qr/quest\(s\) (?:found|shown)/i, 'the command still lists quests');
};

subtest 'quests --page still reaches the request' => sub {
  my ($cli, $ua) = mock_cli();
  my $cmd = $class->new( page => 2 );

  capture_stdout { $cmd->execute([], [$cli]) };

  is(query_of(($ua->seen_uris)[0])->{page}, 2, 'page=2 is sent');
};

done_testing;
