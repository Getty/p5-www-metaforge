#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

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

done_testing;
