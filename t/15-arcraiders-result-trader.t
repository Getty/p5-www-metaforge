#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use_ok('WWW::MetaForge::ArcRaiders::Result::Trader');

subtest 'constructor' => sub {
  my $trader = WWW::MetaForge::ArcRaiders::Result::Trader->new(
    name      => 'TianWen',
    inventory => [
      { name => 'Ferro I', trader_price => 1425, icon => 'https://cdn.metaforge.app/arc-raiders/icons/ferro-i.webp', rarity => 'Rare', item_type => 'Material' },
      { name => 'Angled Grip I', trader_price => 1920, icon => 'https://cdn.metaforge.app/arc-raiders/icons/angled-grip-i.webp', rarity => 'Uncommon', item_type => 'Attachment' },
    ],
    _raw => {},
  );

  is($trader->name, 'TianWen', 'name');
  is(scalar @{$trader->inventory}, 2, 'inventory count');
};

subtest 'from_hashref' => sub {
  my $trader = WWW::MetaForge::ArcRaiders::Result::Trader->from_hashref({
    name      => 'Apollo',
    inventory => [
      { name => 'Barricade Kit', trader_price => 1920, icon => 'https://cdn.metaforge.app/arc-raiders/icons/barricade-kit.webp', rarity => 'Uncommon', item_type => 'Quick Use' },
    ],
  });

  is($trader->name, 'Apollo', 'name');
  is($trader->inventory->[0]{name}, 'Barricade Kit', 'inventory item name');
  is($trader->inventory->[0]{trader_price}, 1920, 'inventory trader_price');
};

subtest 'live API item fields' => sub {
  my $trader = WWW::MetaForge::ArcRaiders::Result::Trader->new(
    name      => 'Test',
    inventory => [
      {
        id            => 'barricade-kit',
        icon          => 'https://cdn.metaforge.app/arc-raiders/icons/barricade-kit.webp',
        name          => 'Barricade Kit',
        value         => 640,
        rarity        => 'Uncommon',
        item_type     => 'Quick Use',
        description   => 'A deployable cover.',
        trader_price  => 1920,
      },
    ],
    _raw => {},
  );

  my $item = $trader->inventory->[0];
  ok(exists $item->{trader_price}, 'item has trader_price');
  ok(exists $item->{icon}, 'item has icon');
  ok(exists $item->{name}, 'item has name');
  ok(exists $item->{rarity}, 'item has rarity');
  ok(exists $item->{item_type}, 'item has item_type');
  is($item->{trader_price}, 1920, 'trader_price correct');
  like($item->{icon}, qr{^https?://}, 'icon is a URL');
};

subtest 'find_item method' => sub {
  my $trader = WWW::MetaForge::ArcRaiders::Result::Trader->new(
    name      => 'Test',
    inventory => [
      { name => 'Ferro I', trader_price => 1425 },
      { name => 'Angled Grip I', trader_price => 1920 },
      { name => 'Heavy Ammo', trader_price => 900 },
    ],
    _raw => {},
  );

  my $found = $trader->find_item('Ferro I');
  ok(defined $found, 'find_item returns result');
  is($found->{trader_price}, 1425, 'found correct item');

  my $found_ci = $trader->find_item('ferro i');  # case insensitive
  ok(defined $found_ci, 'find_item is case insensitive');

  my $not_found = $trader->find_item('NonExistent');
  ok(!defined $not_found, 'find_item returns undef for missing');
};

subtest 'has_item method' => sub {
  my $trader = WWW::MetaForge::ArcRaiders::Result::Trader->new(
    name      => 'Test',
    inventory => [
      { name => 'Ferro I', trader_price => 1425 },
    ],
    _raw => {},
  );

  ok($trader->has_item('Ferro I'), 'has_item returns true for existing');
  ok($trader->has_item('ferro i'), 'has_item is case insensitive');
  ok(!$trader->has_item('NonExistent'), 'has_item returns false for missing');
};

subtest 'empty inventory' => sub {
  my $trader = WWW::MetaForge::ArcRaiders::Result::Trader->from_hashref({
    name => 'Empty Trader',
  });

  is(ref $trader->inventory, 'ARRAY', 'inventory is array');
  is(scalar @{$trader->inventory}, 0, 'inventory is empty');
  ok(!$trader->has_item('Anything'), 'has_item false on empty inventory');
};

done_testing;
