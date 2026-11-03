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

my $Station = 'WWW::MetaForge::ArcRaiders::Result::HideoutStation';
my $Level   = 'WWW::MetaForge::ArcRaiders::Result::HideoutStation::Level';

# The byte-faithful /hideout response: a bare array of stations
my $raw = JSON::MaybeXS->new->decode(path("$FindBin::Bin/fixtures/hideout.json")->slurp_utf8);

my $ua  = MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures");
my $api = WWW::MetaForge::ArcRaiders->new(ua => $ua, cache_dir => tempdir(CLEANUP => 1), use_cache => 0);

my $stations = $api->hideout;
my %station  = map { $_->id => $_ } @$stations;

subtest 'hideout through the facade' => sub {
  is(ref $stations, 'ARRAY', 'ArrayRef');
  is(scalar @$stations, 9, 'nine stations');
  isa_ok($_, $Station) for $stations->[0];
  is_deeply([ map { $_->id } @$stations ],
    [qw( scrappy weapon-bench equipment-bench med-station explosives-bench utility-bench refiner research-station outpost )],
    'ids in API order');
  is_deeply([ map { $_->name } @$stations ],
    ['Scrappy', 'Gunsmith', 'Gear Bench', 'Medical Lab', 'Explosives Station', 'Utility Station', 'Refiner', 'Research Station', 'Outpost'],
    'names');
  is_deeply([ map { $_->max_level } @$stations ], [6, 4, 3, 3, 3, 3, 3, 4, 4], 'max levels');
  is_deeply($api->hideout_raw, $raw, 'hideout_raw is the response');
};

subtest 'Gunsmith (weapon-bench)' => sub {
  my $gunsmith = $station{'weapon-bench'};
  is($gunsmith->name, 'Gunsmith', 'name');
  is($gunsmith->max_level, 4, 'max_level');

  my $one = $gunsmith->level(1);
  isa_ok($one, $Level);
  is($one->number, 1, 'number');
  is_deeply($one->unlock_requirements, [{ id => 'rounds-played', quantity => 3 }], 'level 1 unlock requirement');
  is_deeply($one->required_items,
    [{ id => 'metal-parts', quantity => 20 }, { id => 'rubber-parts-recipe', quantity => 30 }],
    'level 1 takes 20x metal-parts and 30x rubber-parts-recipe');
  is_deeply($one->crafts, [], 'level 1 crafts');

  my $two = $gunsmith->level(2);
  is_deeply($two->required_items,
    [{ id => 'rusted-tools', quantity => 3 }, { id => 'mechanical-components', quantity => 5 }, { id => 'wasp-driver', quantity => 8 }],
    'level 2 takes 3x rusted-tools, 5x mechanical-components, 8x wasp-driver');
  is_deeply($two->unlock_requirements, [], 'level 2 has no unlock requirement');

  ok(!defined $gunsmith->level(9), 'level(9) is undef');
  ok(!defined $gunsmith->level(0), 'level(0) is undef');
};

subtest 'levels are sorted numerically, 1..max_level' => sub {
  for my $s (@$stations) {
    is_deeply([ map { $_->number } @{ $s->levels } ], [ 1 .. $s->max_level ], $s->id . ': levels 1..max_level');
  }
  # keys of the API's levels object are strings: 10 would sort before 2 as a string
  my $ten = $Station->from_hashref({
    id => 'x', name => 'X', maxLevel => 10,
    levels => { map { $_ => {} } 1 .. 10 },
  });
  is_deeply([ map { $_->number } @{ $ten->levels } ], [ 1 .. 10 ], 'numeric, not string order');
};

subtest 'missing level keys become empty lists' => sub {
  my $one = $station{scrappy}->level(1);
  is_deeply($one->_raw, {}, 'Scrappy level 1 is {} in the response');
  is_deeply($one->required_items, [], 'required_items []');
  is_deeply($one->unlock_requirements, [], 'unlock_requirements []');
  is_deeply($one->crafts, [], 'crafts []');
};

subtest 'every level maps its raw keys' => sub {
  for my $rs (@$raw) {
    my $s = $station{ $rs->{id} };
    is($s->id, $rs->{id}, $rs->{id} . ': id');
    is($s->name, $rs->{name}, $rs->{id} . ': name');
    is($s->max_level, $rs->{maxLevel}, $rs->{id} . ': maxLevel');
    is_deeply($s->_raw, $rs, $rs->{id} . ': _raw is the untouched station');
    is(scalar @{ $s->levels }, scalar keys %{ $rs->{levels} }, $rs->{id} . ': one Level per levels key');
    for my $n (sort { $a <=> $b } keys %{ $rs->{levels} }) {
      my ($rl, $l) = ($rs->{levels}{$n}, $s->level($n));
      is_deeply($l->required_items, $rl->{requiredItems} // [], "$rs->{id} $n: requiredItems");
      is_deeply($l->unlock_requirements, $rl->{unlockRequirements} // [], "$rs->{id} $n: unlockRequirements");
      is_deeply($l->crafts, $rl->{crafts} // [], "$rs->{id} $n: crafts");
      is_deeply($l->_raw, $rl, "$rs->{id} $n: _raw");
    }
  }
};

subtest 'key coverage: every key of the response is mapped or skipped' => sub {
  my %station_keys = map { $_ => 1 } map { keys %$_ } @$raw;
  my %level_keys   = map { $_ => 1 } map { keys %$_ } map { values %{ $_->{levels} } } @$raw;

  my %mapped  = (id => 1, name => 1, maxLevel => 1, levels => 1);
  my %skipped = (description => 'not modelled, stays in _raw');
  is_deeply([ sort grep { !$mapped{$_} && !$skipped{$_} } keys %station_keys ], [],
    'no station key outside the mapped and the skip list - a new key means the class needs a look');
  is_deeply([ sort grep { !$station_keys{$_} } keys %mapped ], [], 'every mapped station key still occurs in the fixture');

  my %level_mapped = (requiredItems => 1, unlockRequirements => 1, crafts => 1);
  is_deeply([ sort grep { !$level_mapped{$_} } keys %level_keys ], [], 'no level key outside the mapped list');
  is_deeply([ sort grep { !$level_keys{$_} } keys %level_mapped ], [], 'every mapped level key still occurs in the fixture');

  ok(exists $station{scrappy}->_raw->{description}, 'a skipped key is still in _raw');
};

done_testing;
