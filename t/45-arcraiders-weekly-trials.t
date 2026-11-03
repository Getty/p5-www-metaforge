#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/lib";
use JSON::MaybeXS;
use Path::Tiny;
use MockUA;
use WWW::MetaForge::ArcRaiders;

my $Trial  = 'WWW::MetaForge::ArcRaiders::Result::WeeklyTrial';
my $Window = 'WWW::MetaForge::ArcRaiders::Result::WeeklyTrialWindow';

# The byte-faithful /weekly-trials response: { activeWindowEnd, data, nextWindowStart }
my $raw = JSON::MaybeXS->new->decode(path("$FindBin::Bin/fixtures/weekly-trials.json")->slurp_utf8);

my $api = WWW::MetaForge::ArcRaiders->new(
  ua        => MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures"),
  cache_dir => tempdir(CLEANUP => 1),
  use_cache => 0,
);

my $trials   = $api->weekly_trials;
my @active   = grep { $_->is_active } @$trials;
my @upcoming = grep { $_->upcoming } @$trials;
my @catalog  = grep { !$_->is_active && !$_->upcoming } @$trials;
my %by_id    = map { $_->id => $_ } @$trials;

subtest 'weekly_trials through the facade' => sub {
  is(ref $trials, 'ARRAY', 'ArrayRef');
  is(scalar @$trials, 136, '136 entries');
  isa_ok($trials->[0], $Trial);
  is(scalar @active, 5, '5 active');
  is(scalar @upcoming, 5, '5 upcoming');
  is(scalar @catalog, 126, '126 catalog entries');
  is(scalar(grep { $_->is_active && $_->upcoming } @$trials), 0, 'none is both');
  is_deeply([ map { $_->_raw } @$trials ], $raw->{data}, '_raw of every entry is its record, in API order');
};

subtest 'weekly_trials_window' => sub {
  my $window = $api->weekly_trials_window;
  isa_ok($window, $Window);
  is($window->active_window_end, 1793700000, 'active_window_end: 2026-11-03 10:00 UTC');
  is($window->next_window_start, 1793707200, 'next_window_start: 2026-11-03 12:00 UTC');
  is_deeply($window->_raw, { activeWindowEnd => 1793700000, nextWindowStart => 1793707200 }, '_raw is the envelope without data');
  ok(!exists $window->_raw->{data}, 'no data in _raw');
  is_deeply($api->weekly_trials_raw, $raw, 'weekly_trials_raw is the whole response');

  my ($first_active, $first_upcoming) = ($active[0], $upcoming[0]);
  is($first_active->window_end, $window->active_window_end, 'active trials end with the active window');
  is($first_upcoming->window_start, $window->next_window_start, 'upcoming trials start with the next window');
};

subtest 'active and upcoming trials carry window and objective' => sub {
  is_deeply([ map { $_->name } @active ], [
    'Damage ARC enemies using a Deadline',
    'Damage ARC using a Blaze Grenade',
    'Damage flying ARC enmies using Medium Ammo Weapons',
    'Search Backpacks',
    'Search Husks',
  ], 'active trials, in API order');
  is_deeply([ map { $_->name } @upcoming ], [
    'Damage ARC Turbines', 'Damage Comets', 'Damage Queens or Matriarchs', 'Search ARC Couriers', 'Search Husks',
  ], 'upcoming trials, in API order');

  for my $t (@active) {
    is($t->window_id, 387506147, $t->name . ': window_id');
    is($t->window_start, 1793102400, $t->name . ': window_start in seconds');
  }
  for my $t (@upcoming) {
    is($t->window_id, 847389050, $t->name . ': window_id');
    is($t->window_end, 1794304800, $t->name . ': window_end in seconds');
  }
  ok(defined $_->objective_id && defined $_->multiplier && defined $_->type, $_->name . ': objective, multiplier, type') for @active, @upcoming;
};

subtest 'Search Husks (d9bPJuXx) is bound to Pendola Pass' => sub {
  my $t = $by_id{'weekly-trial:d9bPJuXx:960002156:387506147'};
  isa_ok($t, $Trial);
  is($t->trial_id, 'd9bPJuXx', 'trial_id');
  is($t->name, 'Search Husks', 'name');
  is($t->content_name, 'Search Husks', 'content_name');
  is($t->type, 'Interact', 'type');
  ok($t->is_active, 'is_active');
  ok(!$t->upcoming, 'not upcoming');
  is($t->is_active, 1, 'booleans are 1');
  is($t->upcoming, 0, 'and 0');
  is($t->has_event_header, 1, 'has_event_header');
  is_deeply($t->map_names, ['Pendola Pass'], 'map_names');
  is_deeply($t->map_ids, [1538747736], 'map_ids');
  is($t->multiplier, 400, 'multiplier');
  is($t->objective_id, 960002156, 'objective_id');
  is($t->sort_order, 243, 'sort_order');
  is($t->image_id, 1970149816, 'image_id');
  is($t->image_url, 'https://static.metaforge.app/arc-raiders/weekly-trials/search-husks-on-pendola-pass-v2.webp', 'image_url');
  is($t->guide_link, 'https://metaforge.app/arc-raiders/search-husks-on-pendola-pass', 'guide_link');
  ok(!defined $t->video_link, 'video_link undef');
  is($t->description_key, 'l0c4l1z3d_111282228', 'description_key');
  is(scalar @{ $t->parameters }, 5, 'five parameters');
  is_deeply($t->parameters->[4], { name => 'Target', value => '-552626417' }, 'a parameter keeps name and value as strings');
  is_deeply($t->database_links, [], 'database_links');

  # The other Search Husks (next window) is not bound to a map
  my ($next) = grep { $_->name eq 'Search Husks' && $_->upcoming } @$trials;
  is_deeply($next->map_names, [], 'upcoming Search Husks: no map');
  is_deeply($next->map_ids, [], 'upcoming Search Husks: no map ids');
};

subtest 'catalog entries: null becomes an empty list or undef' => sub {
  my $t = $by_id{'weekly-trial:tSpkG3vp'};
  isa_ok($t, $Trial);
  is($t->name, 'Damage any ARC enemies', 'name');
  is($t->is_active, 0, 'is_active 0');
  is($t->upcoming, 0, 'upcoming 0');
  is($t->has_event_header, 0, 'has_event_header 0');
  ok(!defined $t->type, 'type undef');
  ok(!defined $t->window_id, 'window_id undef');
  ok(!defined $t->window_start, 'window_start undef');
  ok(!defined $t->window_end, 'window_end undef');
  ok(!defined $t->objective_id, 'objective_id undef');
  ok(!defined $t->multiplier, 'multiplier undef');
  ok(!defined $t->image_id, 'image_id undef');
  ok(!defined $t->description_key, 'description_key undef');
  is($t->sort_order, 0, 'sort_order');
  is($t->guide_link, 'https://metaforge.app/arc-raiders/damage-any-arc-enemies', 'guide_link');
  is_deeply($t->parameters, [], 'parameters []');
  is_deeply($t->map_ids, [], 'map_ids []');
  is_deeply($t->map_names, [], 'map_names []');
  is_deeply($t->database_links, [], 'database_links []');

  is(scalar(grep { ref $_->parameters ne 'ARRAY' || @{ $_->parameters } } @catalog), 0, 'parameters [] for all 126 catalog entries');
  is(scalar(grep { ref $_->map_ids ne 'ARRAY' } @$trials), 0, 'map_ids is always a list');
  is(scalar(grep { @{ $_->map_ids } } @catalog), 0, 'no catalog entry has map ids');
  is(scalar(grep { @{ $_->map_ids } } @$trials), 2, 'only two scheduled trials are bound to a map id');
};

subtest 'every attribute follows its key' => sub {
  my %bool = map { $_ => 1 } qw( is_active upcoming has_event_header );
  my %list = map { $_ => 1 } qw( parameters map_ids map_names database_links );
  my @mapped = qw(
    id trial_id name content_name type is_active upcoming has_event_header
    window_id window_start window_end objective_id multiplier parameters
    map_ids map_names sort_order image_url image_id guide_link video_link
    database_links description_key
  );
  my @bad;
  for my $i (0 .. $#$trials) {
    my ($t, $r) = ($trials->[$i], $raw->{data}[$i]);
    for my $key (@mapped) {
      my ($got, $want) = ($t->$key, $r->{$key});
      $want = $want ? 1 : 0 if $bool{$key};
      $want = [] if $list{$key} && !defined $want;
      push @bad, "$r->{id} $key" unless
        ref $want ? eq_array($got, $want) : (defined $want ? defined $got && $got eq $want : !defined $got);
    }
  }
  is_deeply(\@bad, [], 'all 23 mapped keys of all 136 records');
};

subtest 'key coverage: every key of the response is mapped or skipped' => sub {
  my %keys = map { $_ => 1 } map { keys %$_ } @{ $raw->{data} };
  my %mapped = map { $_ => 1 } qw(
    id trial_id name content_name type is_active upcoming has_event_header
    window_id window_start window_end objective_id multiplier parameters
    map_ids map_names sort_order image_url image_id guide_link video_link
    database_links description_key
  );
  my %skipped = (map_condition => 'not modelled, stays in _raw');

  is_deeply([ sort grep { !$mapped{$_} && !$skipped{$_} } keys %keys ], [],
    'no key outside the mapped and the skip list - a new key means the class needs a look');
  is_deeply([ sort grep { !$keys{$_} } keys %mapped ], [], 'every mapped key still occurs in the fixture');
  can_ok($Trial, keys %mapped);
  ok(!$Trial->can('map_condition'), 'map_condition is not an attribute');
  ok(exists $trials->[0]->_raw->{map_condition}, 'but it stays in _raw');

  is_deeply([ sort keys %$raw ], [qw( activeWindowEnd data nextWindowStart )], 'envelope keys: the window mapping reads activeWindowEnd and nextWindowStart');
};

done_testing;
