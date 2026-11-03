#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use JSON::MaybeXS qw( decode_json );
use lib "$FindBin::Bin/lib";

BEGIN {
  eval { require Capture::Tiny };
  if ($@) {
    plan skip_all => 'Capture::Tiny required for CLI tests';
  }
}
use Capture::Tiny qw(capture capture_stdout);
use MockUA;
use RecordingUA;

use_ok('WWW::MetaForge::ArcRaiders::CLI');
use_ok('WWW::MetaForge::ArcRaiders::CLI::Cmd::Item');
use_ok('WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest');
use_ok('WWW::MetaForge::ArcRaiders::CLI::Cmd::Arc');

# The commands print character strings; the CLI puts one UTF-8
# layer on STDOUT/STDERR, so every non-ASCII character leaves the process
# encoded exactly once and without "Wide character" warnings. The captured
# output is therefore bytes: U+2019 is E2 80 99, U+00D7 is C3 97.
#
# Records with non-ASCII text in the fixtures:
#   items.json:  alpine-wardrobe, stat_block.footprint "1 x 2" (U+00D7), the
#                only Latin-1 character - it came out as the single byte D7
#   quests.json: celestes-journals (U+2019), after-rain-comes (U+2014)
#   arcs.json:   bastion, hornet, queen (U+2014), frigate (U+2019)

my $fixtures = "$FindBin::Bin/fixtures";

sub mock_cli {
  my (%opt) = @_;
  my $cli = WWW::MetaForge::ArcRaiders::CLI->new();
  $cli->{json} = 1 if $opt{json};
  $cli->{api} = WWW::MetaForge::ArcRaiders->new(
    ua        => RecordingUA->new(fixtures_dir => $fixtures, filter_by_id => 1),
    cache_dir => tempdir(CLEANUP => 1),
    use_cache => 0,
  );
  return $cli;
}

# The output bytes of a command and the warnings it raised
sub run_cmd {
  my ($class, $args, %opt) = @_;
  my $cli = mock_cli(%opt);
  my @warnings;
  local $SIG{__WARN__} = sub { push @warnings, $_[0] };
  my $output = capture_stdout { $class->new->execute($args, [$cli]) };
  return ($output, \@warnings);
}

my $Item  = 'WWW::MetaForge::ArcRaiders::CLI::Cmd::Item';
my $Quest = 'WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest';
my $Arc   = 'WWW::MetaForge::ArcRaiders::CLI::Cmd::Arc';

subtest 'item: a Latin-1 character comes out as UTF-8 (U+00D7)' => sub {
  my ($output, $warnings) = run_cmd($Item, ['alpine-wardrobe']);
  like($output, qr/^\s+footprint\s+1 \xC3\x97 2$/m, 'footprint: x is C3 97, not the single byte D7');
  unlike($output, qr/(?<![\xC3])\xD7/, 'no lone D7 byte');
  is_deeply($warnings, [], 'no warnings');
};

subtest 'quest and arc: wide characters, no warnings' => sub {
  my ($quest, $quest_warnings) = run_cmd($Quest, ['celestes-journals']);
  like($quest, qr/^Celeste\xE2\x80\x99s Journals$/m, 'quest name: U+2019 is E2 80 99');
  is_deeply($quest_warnings, [], 'quest: no "Wide character" warning');

  my ($dash, $dash_warnings) = run_cmd($Quest, ['after-rain-comes']);
  like($dash, qr/\xE2\x80\x94/, 'quest after-rain-comes: U+2014 is E2 80 94');
  is_deeply($dash_warnings, [], 'quest after-rain-comes: no warning');

  my ($arc, $arc_warnings) = run_cmd($Arc, ['bastion']);
  like($arc, qr/screech\xE2\x80\x94that/, 'arc description: U+2014 is E2 80 94');
  is_deeply($arc_warnings, [], 'arc: no warning');
};

subtest '--json: characters are encoded once (the encoder adds no layer)' => sub {
  my ($output, $warnings) = run_cmd($Quest, ['celestes-journals'], json => 1);
  like($output, qr/"name" : "Celeste\xE2\x80\x99s Journals"/, 'name in the JSON: E2 80 99');
  unlike($output, qr/\xC3\xA2\xC2\x80/, 'not encoded twice');
  is(decode_json($output)->{name}, "Celeste\x{2019}s Journals", 'decodes to the name');
  is_deeply($warnings, [], 'no warnings');
};

# The real script in a subprocess, as a user runs it. The script must not
# put an :encoding(UTF-8) layer on STDOUT itself: the JSON encoders would add
# a second encoding and U+2019 would come out as C3 A2 C2 80 C2 99. The subprocess
# loads t/lib/OfflineLWP.pm, which answers every request from the fixtures
# and keeps the MockUA network lock, so nothing reaches the network.
subtest 'bin/metaforge-arcraiders in a subprocess: UTF-8 exactly once' => sub {
  my $home = tempdir(CLEANUP => 1);
  local $ENV{HOME}                              = $home;
  local $ENV{XDG_CACHE_HOME}                    = $home;
  local $ENV{WWW_METAFORGE_ARCRAIDERS_NO_CACHE} = 1;
  local $ENV{OFFLINE_FIXTURES_DIR}              = $fixtures;
  my @perl = ($^X, "-I$FindBin::Bin/../lib", "-I$FindBin::Bin/lib", '-MOfflineLWP', "$FindBin::Bin/../bin/metaforge-arcraiders");

  my ($stdout, $stderr, $exit) = capture { system @perl, '--json', 'quest', 'celestes-journals' };
  is($exit, 0, '--json quest: exit 0');
  like($stdout, qr/"name" : "Celeste\xE2\x80\x99s Journals"/, '--json quest: U+2019 once, E2 80 99');
  unlike($stdout, qr/\xC3\xA2\xC2\x80\xC2\x99/, '--json quest: not C3 A2 C2 80 C2 99');
  is($stderr, '', '--json quest: nothing on STDERR');

  ($stdout, $stderr, $exit) = capture { system @perl, 'item', 'alpine-wardrobe' };
  is($exit, 0, 'item: exit 0');
  like($stdout, qr/^\s+footprint\s+1 \xC3\x97 2$/m, 'item: U+00D7 is C3 97');
  is($stderr, '', 'item: nothing on STDERR');

  ($stdout, $stderr, $exit) = capture { system @perl, 'quest', 'celestes-journals' };
  like($stdout, qr/^Celeste\xE2\x80\x99s Journals$/m, 'quest: U+2019 is E2 80 99');
  is($stderr, '', 'quest: no "Wide character" warning on STDERR');
};

# Last on purpose: the layer stays on the process handles after a command
subtest 'prepare_output does not stack layers' => sub {
  my $cli = WWW::MetaForge::ArcRaiders::CLI->new();
  my $encodings = sub { scalar grep { /^encoding\(/ } PerlIO::get_layers(STDOUT, output => 1) };

  my ($twice, $stdout_utf8);
  capture_stdout {
    $cli->prepare_output;
    $cli->prepare_output;
    $twice = $encodings->();
  };
  is($twice, 1, 'two calls: one :encoding layer on STDOUT');

  capture_stdout {
    binmode STDOUT, ':utf8';
    $cli->prepare_output;
    $stdout_utf8 = $encodings->();
  };
  is($stdout_utf8, 0, 'a :utf8 handle is left as it is');
};

done_testing;
