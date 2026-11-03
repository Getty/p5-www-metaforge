#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use JSON::MaybeXS qw(decode_json);

use_ok('WWW::MetaForge::ArcRaiders::Result::Item');

subtest 'constructor with all fields' => sub {
  my $item = WWW::MetaForge::ArcRaiders::Result::Item->new(
    id            => 'ferro-i',
    name          => 'Ferro I',
    description   => 'Heavy break-action rifle.',
    item_type     => 'Weapon',
    loadout_slots => ['Primary'],
    icon          => 'icons/ferro-i.png',
    rarity        => 'Common',
    value         => 475,
    workbench     => 'Weapons',
    stat_block    => { weight => 8.0, stackSize => 1, damage => 40 },
    weight        => 8.0,
    stack_size    => 1,
    _raw          => {},
  );

  is($item->id, 'ferro-i', 'id');
  is($item->name, 'Ferro I', 'name');
  is($item->item_type, 'Weapon', 'item_type');
  is($item->rarity, 'Common', 'rarity');
  is($item->weight, 8.0, 'weight');
  is($item->stack_size, 1, 'stack_size');
  is($item->value, 475, 'value');
  is($item->stat_block->{damage}, 40, 'stat_block.damage');
};

subtest 'from_hashref with API field names' => sub {
  my $data = {
    id            => 'angled-grip-i',
    name          => 'Angled Grip I',
    item_type     => 'Modification',
    rarity        => 'Common',
    description   => 'Reduces recoil.',
    value         => 640,
    icon          => 'icons/angled-grip-i.png',
    loadout_slots => ['Mod1'],
    workbench     => 'Weapons',
    stat_block    => {
      weight    => 0.25,
      stackSize => 1,
    },
  };

  my $item = WWW::MetaForge::ArcRaiders::Result::Item->from_hashref($data);

  is($item->id, 'angled-grip-i', 'id from hashref');
  is($item->name, 'Angled Grip I', 'name from hashref');
  is($item->item_type, 'Modification', 'item_type from hashref');
  is($item->value, 640, 'value from hashref');
  is($item->icon, 'icons/angled-grip-i.png', 'icon from hashref');
  is_deeply($item->loadout_slots, ['Mod1'], 'loadout_slots from hashref');
  is($item->workbench, 'Weapons', 'workbench from hashref');
  is($item->weight, 0.25, 'weight extracted from stat_block');
  is($item->stack_size, 1, 'stack_size extracted from stat_block');
  is($item->stat_block->{weight}, 0.25, 'stat_block.weight preserved');
  is($item->stat_block->{stackSize}, 1, 'stat_block.stackSize preserved');
};

subtest 'from_hashref with minimal data' => sub {
  my $item = WWW::MetaForge::ArcRaiders::Result::Item->from_hashref({
    id   => 'test-item',
    name => 'Test Item',
  });

  is($item->id, 'test-item', 'id set');
  is($item->name, 'Test Item', 'name set');
  ok(!defined $item->rarity, 'rarity is undef');
  ok(!defined $item->item_type, 'item_type is undef');
  ok(!defined $item->value, 'value is undef');
  is_deeply($item->loadout_slots, [], 'loadout_slots defaults to []');
};

subtest 'loadout_slots defaults to empty array' => sub {
  my $item = WWW::MetaForge::ArcRaiders::Result::Item->from_hashref({
    id   => 'test',
    name => 'Test',
  });

  is(ref $item->loadout_slots, 'ARRAY', 'loadout_slots is array');
  is(scalar @{$item->loadout_slots}, 0, 'loadout_slots is empty');
};

subtest '_raw preserves original data' => sub {
  my $original = { id => 'test', name => 'Test', custom_field => 'custom_value' };
  my $item = WWW::MetaForge::ArcRaiders::Result::Item->from_hashref($original);

  is_deeply($item->_raw, $original, '_raw contains original data');
  is($item->_raw->{custom_field}, 'custom_value', 'custom fields accessible via _raw');
};

# Page 1 of the live items endpoint (?page=1&includeComponents=true), byte-faithful.
sub fixture_item {
  my ($id) = @_;
  my $file = "$FindBin::Bin/fixtures/items.json";
  open my $fh, '<:raw', $file or die "Cannot open $file: $!";
  my $payload = decode_json(do { local $/; <$fh> });
  close $fh;
  my ($data) = grep { $_->{id} eq $id } @{ $payload->{data} };
  die "item $id is not on page 1 of the fixture" unless $data;
  return WWW::MetaForge::ArcRaiders::Result::Item->from_hashref($data);
}

subtest 'used_in from the items fixture' => sub {
  my $item = fixture_item('advanced-arc-powercell');

  is(ref $item->used_in, 'ARRAY', 'used_in is an array');
  is_deeply(
    [ map { $_->{quantity} . 'x' . $_->{item}{id} } @{ $item->used_in } ],
    [ '1xenergy-ammo', '3xjolt-mine-recipe', '2xtactical-mk3-defensive-blueprint', '1xsurge-shield-recharger' ],
    'used_in carries all four entries with quantity and item id, in API order',
  );
};

subtest 'recycle_from and dropped_by from the items fixture' => sub {
  my $item = fixture_item('advanced-arc-powercell');

  is_deeply(
    [ map { $_->{quantity} . 'x' . $_->{item}{id} } @{ $item->recycle_from } ],
    [ '2xfrigate-inductor', '4xassessor-matrix' ],
    'recycle_from: items that yield this item, with the yield quantity',
  );
  is(scalar @{ $item->dropped_by }, 11, 'dropped_by: eleven ARCs');
  is_deeply(
    [ map { $_->{arc_id} } @{ $item->dropped_by }[0 .. 2] ],
    [qw( bison comet turbine )],
    'dropped_by: arc_id of the first entries',
  );
  my $first = $item->dropped_by->[0];
  is($first->{arc}{name}, 'Leaper', 'dropped_by: nested arc name');
  is($first->{id}, '0211e0dc-a172-44cb-a536-d5d18be67cba', 'dropped_by: entry id');
  is($first->{created_at}, '2025-11-04T15:59:19.422889+00:00', 'dropped_by: entry created_at');
  is_deeply($item->_raw->{dropped_by}, $item->dropped_by, 'dropped_by is the raw list');
};

subtest 'scalar attributes from the items fixture' => sub {
  my $item = fixture_item('advanced-arc-powercell');

  is($item->subcategory, 'Topside Material', 'subcategory');
  is($item->loot_area, 'ARC', 'loot_area');
  is($item->created_at, '2025-10-17T23:09:59.354807+00:00', 'created_at');
  is($item->updated_at, '2026-10-09T09:06:05.083+00:00', 'updated_at');
  is($item->flavor_text, '', 'flavor_text keeps the empty string the API sends');
  is($item->ammo_type, '', 'ammo_type keeps the empty string the API sends');
  like($item->article, qr{^<p>The <strong>Advanced ARC Powercell</strong> is a resource}, 'article is the HTML text');

  my $weapon = fixture_item('amplified-anvil');
  is($weapon->ammo_type, 'Heavy', 'ammo_type of a weapon');
  is($weapon->subcategory, 'Hand Cannon', 'subcategory of a weapon');

  my $duck = fixture_item('alien-duck');
  is($duck->flavor_text, 'Can be thrown to create noise.', 'flavor_text with text');

  my $outfit = fixture_item('abyss-outfit');
  is($outfit->subcategory, 'Outfit', 'subcategory of an outfit');
  is($outfit->created_at, '2026-10-01T12:31:58.238411+00:00', 'created_at of an outfit');
  ok(!defined $outfit->flavor_text, 'flavor_text null -> undef');
  ok(!defined $outfit->loot_area, 'loot_area null -> undef');
  ok(!defined $outfit->ammo_type, 'ammo_type null -> undef');
};

subtest 'relationships from the items fixture' => sub {
  my $item = fixture_item('advanced-arc-powercell');
  is_deeply(
    [ sort keys %{ $item->relationships } ],
    [qw( operations recycling updatedAt )],
    'relationships keeps the API keys (camelCase) unchanged',
  );
  is(scalar @{ $item->relationships->{operations} }, 3, 'three operations');
  is(scalar @{ $item->relationships->{recycling} }, 1, 'one recycling relation');
  is($item->relationships->{operations}[0]{id}, 'offer:128191464', 'operation id');
  is($item->relationships->{operations}[0]{durationSeconds}, 360, 'operation durationSeconds');

  my $outfit = fixture_item('abyss-outfit');
  is_deeply(
    $outfit->relationships,
    { recycling => [], updatedAt => '2026-10-27T12:30:24.714+00:00' },
    'relationships of an outfit',
  );
};

subtest 'cosmetic from the items fixture' => sub {
  my $outfit = fixture_item('abyss-outfit');
  is($outfit->cosmetic->{kind}, 'Outfit', 'cosmetic kind');
  is($outfit->cosmetic->{slot}, 'Outfit', 'cosmetic slot');
  is(scalar @{ $outfit->cosmetic->{settings} }, 5, 'five settings');
  is($outfit->cosmetic->{settings}[0]{name}, 'Color', 'first setting name');
  is_deeply(
    [ map { $_->{name} } @{ $outfit->cosmetic->{settings}[0]{options} } ],
    [ 'Blue Yellow', 'Black Yellow', 'Green White' ],
    'options of the first setting',
  );

  my $plain = fixture_item('advanced-arc-powercell');
  is_deeply($plain->cosmetic, {}, 'cosmetic null -> {}');
};

subtest 'without includeComponents the relations are absent and default' => sub {
  my $record = { %{ fixture_item('advanced-arc-powercell')->_raw } };
  delete @{$record}{qw( components dropped_by mods recycle_components recycle_from relationships sold_by used_in )};
  my $item = WWW::MetaForge::ArcRaiders::Result::Item->from_hashref($record);

  is_deeply($item->recycle_from, [], 'recycle_from defaults to []');
  is_deeply($item->dropped_by, [], 'dropped_by defaults to []');
  is_deeply($item->mods, [], 'mods defaults to []');
  is_deeply($item->used_in, [], 'used_in defaults to []');
  is_deeply($item->relationships, {}, 'relationships defaults to {}');
  is($item->subcategory, 'Topside Material', 'plain columns are still read');
};

subtest 'null relations from the API' => sub {
  my $item = WWW::MetaForge::ArcRaiders::Result::Item->from_hashref({
    id => 'x', name => 'X', relationships => undef, cosmetic => undef,
  });
  is_deeply($item->relationships, {}, 'relationships null -> {}');
  is_deeply($item->cosmetic, {}, 'cosmetic null -> {}');
  is($item->unlocks_weapon, 0, 'unlocks_weapon absent -> 0');
};

subtest 'used_in defaults to empty array' => sub {
  my $item = WWW::MetaForge::ArcRaiders::Result::Item->from_hashref({
    id => 'test', name => 'Test',
  });

  is_deeply($item->used_in, [], 'used_in defaults to []');
};

done_testing;
