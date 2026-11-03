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
use Capture::Tiny qw(capture);

use_ok('WWW::MetaForge::ArcRaiders::CLI');
use_ok('WWW::MetaForge::ArcRaiders::CLI::Cmd::Items');

# karr k34: the command line arrives as bytes; the CLI decodes @ARGV from
# UTF-8 before MooX::Cmd and MooX::Options read it, so an argument is a
# character string like the names in the API data. Before, quest
# "Celeste's Journals" (U+2019) never matched and the "not found" message
# came out double-encoded (C3 A2 C2 80 C2 99).
#
# fixtures/quests.json: "Celeste\x{2019}s Journals", id celestes-journals.
# The arguments below are written as bytes: U+2019 is E2 80 99.

my $fixtures = "$FindBin::Bin/fixtures";

# The real script in a subprocess with the offline LWP shim (answers from the
# fixtures, keeps the MockUA network lock). Arguments are passed as bytes.
sub run_bin {
  my ($args, %env) = @_;
  my $home = tempdir(CLEANUP => 1);
  local $ENV{HOME}                              = $home;
  local $ENV{XDG_CACHE_HOME}                    = $home;
  local $ENV{WWW_METAFORGE_ARCRAIDERS_NO_CACHE} = 1;
  local $ENV{OFFLINE_FIXTURES_DIR}              = $fixtures;
  local $ENV{$_}                                = $env{$_} for keys %env;
  my @perl = ($^X, "-I$FindBin::Bin/../lib", "-I$FindBin::Bin/lib", '-MOfflineLWP',
    "$FindBin::Bin/../bin/metaforge-arcraiders");
  my ($stdout, $stderr, $exit) = capture { system @perl, @$args };
  return ($stdout, $stderr, $exit);
}

subtest 'quest "Celeste<U+2019>s Journals" finds the quest' => sub {
  my ($stdout, $stderr, $exit) = run_bin(['quest', "Celeste\xE2\x80\x99s Journals"]);
  is($exit, 0, 'exit 0');
  is($stderr, '', 'nothing on STDERR');
  like($stdout, qr/^Celeste\xE2\x80\x99s Journals$/m, 'name: U+2019 once, E2 80 99');
  like($stdout, qr/ID:\s+celestes-journals/, 'the right quest: id celestes-journals');
  unlike($stdout, qr/not found/, 'not "not found"');
};

subtest 'lower case matches too' => sub {
  my ($stdout, $stderr, $exit) = run_bin(['quest', "celeste\xE2\x80\x99s journals"]);
  is($exit, 0, 'exit 0');
  is($stderr, '', 'nothing on STDERR');
  like($stdout, qr/ID:\s+celestes-journals/, 'found: id celestes-journals');
};

subtest 'not found: the message repeats the argument encoded once' => sub {
  my ($stdout, $stderr, $exit) = run_bin(['quest', "Nope\xE2\x80\x99s"]);
  like($stdout, qr/Quest 'Nope\xE2\x80\x99s' not found\./, 'message with E2 80 99');
  unlike($stdout, qr/\xC3\xA2\xC2\x80\xC2\x99/, 'not C3 A2 C2 80 C2 99 (double encoding)');
  is($stderr, '', 'nothing on STDERR');
};

subtest 'an argument that is not UTF-8 fails loud' => sub {
  my ($stdout, $stderr, $exit) = run_bin(['quest', "Caf\xE9"]);
  isnt($exit, 0, 'exit not 0');
  like($stderr, qr/not UTF-8/, 'STDERR names the problem');
  unlike($stdout, qr/not found/, 'no lookup was made');
};

subtest 'PERL_UNICODE=A: perl decoded @ARGV already, no second decoding' => sub {
  my ($stdout, $stderr, $exit) = run_bin(['quest', "Celeste\xE2\x80\x99s Journals"], PERL_UNICODE => 'A');
  is($exit, 0, 'exit 0');
  is($stderr, '', 'nothing on STDERR');
  like($stdout, qr/ID:\s+celestes-journals/, 'found: id celestes-journals');
  like($stdout, qr/^Celeste\xE2\x80\x99s Journals$/m, 'name: U+2019 once, E2 80 99');
};

# In process: an option value goes through the same @ARGV
subtest 'option value: --search is a character string' => sub {
  my $items = 'WWW::MetaForge::ArcRaiders::CLI::Cmd::Items';
  my $seen;
  {
    no warnings qw(redefine once);
    local *WWW::MetaForge::ArcRaiders::CLI::Cmd::Items::execute = sub { $seen = $_[0] };
    local @ARGV = ('items', '--search', "Celeste\xE2\x80\x99s");
    WWW::MetaForge::ArcRaiders::CLI->new_with_cmd;
  }
  isa_ok($seen, $items, 'the items command ran (stubbed)');
  is($seen->search, "Celeste\x{2019}s", '--search is "Celeste\x{2019}s"');
  is(length $seen->search, 9, 'nine characters (not the 11 bytes)');
};

done_testing;
