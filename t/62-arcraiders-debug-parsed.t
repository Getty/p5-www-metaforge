#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use JSON::MaybeXS qw( decode_json );
use Path::Tiny;
use lib "$FindBin::Bin/lib";
use MockUA;
use WWW::MetaForge::ArcRaiders;

# The debug line "PARSED: <n> records" counts the records of the response:
# the entries of data for a response with an envelope, the entries of the
# list for a bare list. The expected numbers come from the fixtures.

my $dir = "$FindBin::Bin/fixtures";
sub fixture { return decode_json(path("$dir/$_[0].json")->slurp_raw) }

# The debug messages of one call
sub debug_of {
  my ($call) = @_;
  my @warnings;
  local $SIG{__WARN__} = sub { push @warnings, @_ };
  my $api = WWW::MetaForge::ArcRaiders->new(
    ua        => MockUA->new(fixtures_dir => $dir),
    use_cache => 0,
    debug     => 1,
  );
  $call->($api);
  return @warnings;
}

sub parsed_counts {
  return map { /PARSED: (\d+) records/ ? $1 : () } @_;
}

subtest 'items: the entries of data' => sub {
  my $expected = scalar @{ fixture('items')->{data} };
  cmp_ok($expected, '>', 1, 'the fixture holds several items');
  is_deeply([ parsed_counts(debug_of(sub { $_[0]->items })) ], [$expected],
    'one PARSED line with the number of items');
};

subtest 'events-schedule: the entries of data' => sub {
  my $expected = scalar @{ fixture('events-schedule')->{data} };
  cmp_ok($expected, '>', 1, 'the fixture holds several records');
  is_deeply([ parsed_counts(debug_of(sub { $_[0]->event_timers })) ], [$expected],
    'one PARSED line with the number of records');
};

subtest 'weekly-trials: the entries of data' => sub {
  my $expected = scalar @{ fixture('weekly-trials')->{data} };
  cmp_ok($expected, '>', 1, 'the fixture holds several trials');
  is_deeply([ parsed_counts(debug_of(sub { $_[0]->weekly_trials })) ], [$expected],
    'one PARSED line with the number of trials');
};

subtest 'hideout: the entries of the bare list' => sub {
  my $expected = scalar @{ fixture('hideout') };
  cmp_ok($expected, '>', 1, 'the fixture holds several stations');
  is_deeply([ parsed_counts(debug_of(sub { $_[0]->hideout })) ], [$expected],
    'one PARSED line with the number of stations');
};

subtest 'traders: the count is reported' => sub {
  my @counts = parsed_counts(debug_of(sub { $_[0]->traders }));
  is(scalar @counts, 1, 'one PARSED line');
  diag('traders: PARSED: '.$counts[0].' records');
};

done_testing;
