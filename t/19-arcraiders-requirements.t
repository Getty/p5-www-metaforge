#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/lib";

use_ok('WWW::MetaForge::ArcRaiders');

my $cache_dir = tempdir(CLEANUP => 1);

# Always use MockUA for these tests - we need predictable fixture data
diag("Using MockUA for requirements tests");
require MockUA;
my $api = WWW::MetaForge::ArcRaiders->new(
  ua        => MockUA->new(fixtures_dir => "$FindBin::Bin/fixtures"),
  cache_dir => $cache_dir,
  use_cache => 0,
);

# Fixture crafting chain (real items, from t/fixtures/items.json, verified
# against the live API via `curl "https://metaforge.app/api/arc-raiders/items?includeComponents=true&limit=200"`):
#
#   Adrenaline Shot          -> Plastic Parts x3, Chemicals x3
#   Advanced Electrical Components -> Wires x3, Electrical Components x2
#   Electrical Components    -> Plastic Parts x8, Rubber Parts x4
#   Wires / Rubber Parts / Plastic Parts / Chemicals -> base materials (no components)

subtest 'find_item_by_name works' => sub {
  my $item = $api->find_item_by_name('Electrical Components');
  ok($item, 'found Electrical Components');
  is($item->name, 'Electrical Components', 'correct name');
  is($item->id, 'electrical-components', 'correct id');

  my $not_found = $api->find_item_by_name('Nonexistent Item');
  ok(!$not_found, 'returns undef for missing item');

  # Case insensitive
  my $lower = $api->find_item_by_name('electrical components');
  ok($lower, 'case insensitive search works');
  is($lower->name, 'Electrical Components', 'found correct item with lowercase');
};

subtest 'find_item_by_id works' => sub {
  my $item = $api->find_item_by_id('electrical-components');
  ok($item, 'found by id');
  is($item->name, 'Electrical Components', 'correct name');
};

subtest 'calculate_requirements - single item with components' => sub {
  my $result = $api->calculate_requirements(
    items => [{ item => 'Advanced Electrical Components', count => 1 }]
  );

  ok($result, 'got result');
  ok(ref $result->{requirements} eq 'ARRAY', 'requirements is array');
  ok(ref $result->{missing} eq 'ARRAY', 'missing is array');

  # Advanced Electrical Components requires: Wires (3), Electrical Components (2)
  my %by_name = map { $_->{item}->name => $_->{count} } @{$result->{requirements}};

  is($by_name{'Wires'}, 3, 'needs 3 Wires');
  is($by_name{'Electrical Components'}, 2, 'needs 2 Electrical Components');
};

subtest 'calculate_requirements - item with count > 1' => sub {
  my $result = $api->calculate_requirements(
    items => [{ item => 'Advanced Electrical Components', count => 2 }]
  );

  my %by_name = map { $_->{item}->name => $_->{count} } @{$result->{requirements}};

  is($by_name{'Wires'}, 6, 'needs 6 Wires for 2x Advanced Electrical Components');
  is($by_name{'Electrical Components'}, 4, 'needs 4 Electrical Components for 2x Advanced Electrical Components');
};

subtest 'calculate_requirements - item without components' => sub {
  my $result = $api->calculate_requirements(
    items => [{ item => 'Wires', count => 5 }]
  );

  is(scalar @{$result->{requirements}}, 0, 'no requirements for base material');
  is(scalar @{$result->{missing}}, 1, 'one missing entry');
  is($result->{missing}[0]{reason}, 'not_craftable', 'marked as not craftable');
};

subtest 'calculate_requirements - missing item' => sub {
  my $result = $api->calculate_requirements(
    items => [{ item => 'Nonexistent Weapon', count => 1 }]
  );

  is(scalar @{$result->{requirements}}, 0, 'no requirements');
  is(scalar @{$result->{missing}}, 1, 'one missing entry');
  is($result->{missing}[0]{reason}, 'not_found', 'marked as not found');
};

subtest 'calculate_base_requirements - resolves crafting chain' => sub {
  # Advanced Electrical Components -> Wires (3) + Electrical Components (2)
  # Electrical Components -> Plastic Parts (8) + Rubber Parts (4)
  # So Advanced Electrical Components base requirements (count=1):
  #   Wires: 3
  #   Plastic Parts: 8 * 2 = 16
  #   Rubber Parts: 4 * 2 = 8

  my $result = $api->calculate_base_requirements(
    items => [{ item => 'Advanced Electrical Components', count => 1 }]
  );

  ok($result, 'got result');

  my %by_name = map { $_->{item}->name => $_->{count} } @{$result->{requirements}};

  is($by_name{'Wires'}, 3, 'needs 3 Wires (direct base material)');
  is($by_name{'Plastic Parts'}, 16, 'needs 16 Plastic Parts total');
  is($by_name{'Rubber Parts'}, 8, 'needs 8 Rubber Parts');

  # Electrical Components should NOT be in base requirements - it's craftable
  ok(!exists $by_name{'Electrical Components'}, 'Electrical Components resolved to base materials');
};

subtest 'calculate_base_requirements - multiple items' => sub {
  my $result = $api->calculate_base_requirements(
    items => [
      { item => 'Advanced Electrical Components', count => 1 },
      { item => 'Adrenaline Shot', count => 2 },
    ]
  );

  my %by_name = map { $_->{item}->name => $_->{count} } @{$result->{requirements}};

  # Advanced Electrical Components: Wires (3), Plastic Parts (16), Rubber Parts (8)
  # Adrenaline Shot x2: Plastic Parts (3*2=6), Chemicals (3*2=6)
  # Total Plastic Parts: 16 + 6 = 22 (accumulated across both requested items)

  is($by_name{'Wires'}, 3, 'needs 3 Wires');
  is($by_name{'Plastic Parts'}, 22, 'needs 22 Plastic Parts total (summed across both items)');
  is($by_name{'Rubber Parts'}, 8, 'needs 8 Rubber Parts');
  is($by_name{'Chemicals'}, 6, 'needs 6 Chemicals');
};

subtest 'clear_items_cache works' => sub {
  # Ensure cache is populated
  $api->find_item_by_name('Wires');
  ok($api->_items_cache, 'cache is populated');

  $api->clear_items_cache;
  ok(!$api->_items_cache, 'cache is cleared');
};

done_testing;
