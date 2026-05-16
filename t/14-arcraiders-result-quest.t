#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use_ok('WWW::MetaForge::ArcRaiders::Result::Quest');

subtest 'constructor' => sub {
  my $quest = WWW::MetaForge::ArcRaiders::Result::Quest->new(
    id             => 'a-bad-feeling',
    name           => 'A Bad Feeling',
    objectives     => ['Find ARC Probe', 'Search it'],
    xp             => 100,
    granted_items  => [],
    locations      => [],
    marker_category => 'main',
    image          => 'https://example.com/quest.png',
    guide_links    => [],
    trader_name    => 'Trader Joe',
    sort_order     => 1,
    position       => { x => 10, y => 20 },
    required_items => [],
    rewards        => [
      {
        id       => 'abc123',
        item     => { id => 'metal-parts', icon => 'metal.png', name => 'Metal Parts', rarity => 'common', item_type => 'material' },
        item_id  => 'metal-parts',
        quantity => '5',
      },
    ],
    _raw           => {},
  );

  is($quest->id, 'a-bad-feeling', 'id');
  is($quest->name, 'A Bad Feeling', 'name');
  is(scalar @{$quest->objectives}, 2, 'objectives count');
  is($quest->xp, 100, 'xp');
  is($quest->trader_name, 'Trader Joe', 'trader_name');
  is($quest->sort_order, 1, 'sort_order');
  is($quest->position->{x}, 10, 'position x');
  is($quest->position->{y}, 20, 'position y');
  is(scalar @{$quest->rewards}, 1, 'rewards count');
  is($quest->rewards->[0]{item}{name}, 'Metal Parts', 'nested rewards item name');
  is($quest->rewards->[0]{quantity}, '5', 'rewards quantity is string');
};

subtest 'from_hashref' => sub {
  my $quest = WWW::MetaForge::ArcRaiders::Result::Quest->from_hashref({
    id           => 'upgrade-stash',
    name         => 'Upgrade Stash Capacity',
    objectives   => ['Collect Scrap'],
    xp           => 50,
    grantedItems => [{ id => 'small-stash', name => 'Small Stash', icon => 'stash.png', rarity => 'common', item_type => 'container' }],
    createdAt    => '2024-01-01T00:00:00Z',
    updatedAt    => '2024-01-02T00:00:00Z',
    locations    => ['Base Camp'],
    markerCategory => 'side',
    image        => 'https://example.com/stash.png',
    guideLinks   => ['https://guide.example.com/stash'],
    traderName   => 'Trader Jane',
    sortOrder    => 5,
    position     => { x => 100, y => 200 },
    requiredItems => [
      { item => 'Scrap Metal', quantity => 100 },
    ],
    rewards => [
      {
        id       => 'def456',
        item     => { id => 'xp-boost', icon => 'boost.png', name => 'XP Boost', rarity => 'rare', item_type => 'consumable' },
        item_id  => 'xp-boost',
        quantity => '3',
      },
    ],
  });

  is($quest->name, 'Upgrade Stash Capacity', 'name');
  is($quest->xp, 50, 'xp mapped');
  is($quest->created_at, '2024-01-01T00:00:00Z', 'created_at');
  is($quest->updated_at, '2024-01-02T00:00:00Z', 'updated_at');
  is($quest->locations->[0], 'Base Camp', 'locations');
  is($quest->marker_category, 'side', 'marker_category');
  is($quest->image, 'https://example.com/stash.png', 'image');
  is($quest->guide_links->[0], 'https://guide.example.com/stash', 'guide_links');
  is($quest->trader_name, 'Trader Jane', 'trader_name');
  is($quest->sort_order, 5, 'sort_order');
  is($quest->position->{x}, 100, 'position x from hashref');
  is($quest->required_items->[0]{item}, 'Scrap Metal', 'required_items mapped');
  is($quest->rewards->[0]{item}{name}, 'XP Boost', 'nested rewards item name from hashref');
  is($quest->rewards->[0]{quantity}, '3', 'rewards quantity is string from hashref');
  is($quest->granted_items->[0]{name}, 'Small Stash', 'granted_items mapped');
};

subtest 'defaults' => sub {
  my $quest = WWW::MetaForge::ArcRaiders::Result::Quest->from_hashref({
    id   => 'minimal',
    name => 'Minimal Quest',
  });

  is(ref $quest->objectives, 'ARRAY', 'objectives is array');
  is(ref $quest->granted_items, 'ARRAY', 'granted_items is array');
  is(ref $quest->locations, 'ARRAY', 'locations is array');
  is(ref $quest->guide_links, 'ARRAY', 'guide_links is array');
  is(ref $quest->required_items, 'ARRAY', 'required_items is array');
  is(ref $quest->rewards, 'ARRAY', 'rewards is array');
  is(scalar @{$quest->objectives}, 0, 'objectives empty');
  is(scalar @{$quest->granted_items}, 0, 'granted_items empty');
};

done_testing;