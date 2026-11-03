#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use JSON::MaybeXS ();
use lib "$FindBin::Bin/lib";

BEGIN {
  eval { require Capture::Tiny };
  if ($@) {
    plan skip_all => 'Capture::Tiny required for CLI tests';
  }
}
use Capture::Tiny qw(capture);

# karr k40: every command that prints JSON uses the same encoder,
# JSON::MaybeXS->new(pretty => 1, canonical => 1), so the output is
# deterministic (sorted keys). The check: decode the output of the real
# script and encode it again with a canonical encoder - a byte-identical
# result means the script's output had sorted keys and the same layout.
# Without canonical a hash with several keys comes out in perl's random
# key order, and the comparison fails.
#
# Not covered: an unknown/empty result prints no JSON; "map" without a map id
# and "event" without a name print usage text.

my $fixtures = "$FindBin::Bin/fixtures";
my $canonical = JSON::MaybeXS->new(utf8 => 1, pretty => 1, canonical => 1);

sub run_bin {
  my (@args) = @_;
  my $home = tempdir(CLEANUP => 1);
  local $ENV{HOME}                              = $home;
  local $ENV{XDG_CACHE_HOME}                    = $home;
  local $ENV{WWW_METAFORGE_ARCRAIDERS_NO_CACHE} = 1;
  local $ENV{OFFLINE_FIXTURES_DIR}              = $fixtures;
  my @perl = ($^X, "-I$FindBin::Bin/../lib", "-I$FindBin::Bin/lib", '-MOfflineLWP',
    "$FindBin::Bin/../bin/metaforge-arcraiders");
  return capture { system @perl, '--json', @args };
}

my @commands = (
  [ 'quest',          'celestes-journals' ],
  [ 'quests' ],
  [ 'item',           'alpine-wardrobe' ],
  [ 'items' ],
  [ 'arc',            'bastion' ],
  [ 'arcs' ],
  [ 'trader',         'Celeste' ],
  [ 'traders' ],
  [ 'event',          'Harvester', '--map', 'Dam' ],
  [ 'events' ],
  [ 'ermal' ],
  [ 'hideout' ],
  [ 'hideout',        'scrappy' ],
  [ 'map',            'dam' ],
  [ 'trials' ],
);

for my $cmd (@commands) {
  subtest '--json '.join(' ', @$cmd).': canonical, pretty' => sub {
    my ($stdout, $stderr, $exit) = run_bin(@$cmd);
    is($exit, 0, 'exit 0');
    is($stderr, '', 'nothing on STDERR');
    my $data = eval { $canonical->decode($stdout) };
    ok(defined $data, 'the output is JSON') or return diag $@;
    ok(ref $data && (ref $data eq 'HASH' ? keys %$data : @$data), 'not empty');
    ok($stdout eq $canonical->encode($data), 'output eq canonical pretty re-encoding');
  };
}

done_testing;
