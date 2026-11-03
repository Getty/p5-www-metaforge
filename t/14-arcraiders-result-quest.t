#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use JSON::MaybeXS qw( decode_json );
use Path::Tiny;

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
        id       => 0,
        item     => { id => 'metal-parts', icon => 'metal.png', name => 'Metal Parts', rarity => 'common', item_type => 'material' },
        item_id  => 'metal-parts',
        quantity => 5,
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
  is($quest->rewards->[0]{quantity}, 5, 'rewards quantity');
};

subtest 'from_hashref' => sub {
  my $quest = WWW::MetaForge::ArcRaiders::Result::Quest->from_hashref({
    id            => 'upgrade-stash',
    name          => 'Upgrade Stash Capacity',
    objectives    => ['Collect Scrap'],
    xp            => 50,
    granted_items => [
      {
        id       => 0,
        item     => { id => 'small-stash', icon => 'stash.png', name => 'Small Stash', rarity => 'Common', item_type => 'Container' },
        item_id  => 'small-stash',
        quantity => 1,
      },
    ],
    created_at      => '2024-01-01T00:00:00Z',
    updated_at      => '2024-01-02T00:00:00Z',
    locations       => [{ x => 100, y => 200, map => 'dam' }],
    marker_category => 'side',
    image           => 'https://example.com/stash.png',
    guide_links     => [{ url => 'https://guide.example.com/stash', label => 'Upgrade Stash Capacity Quest Guide' }],
    guide_url       => '/arc-raiders/upgrade-stash-capacity-arc-raiders',
    trader_name     => 'Trader Jane',
    sort_order      => 5,
    position        => { x => 100, y => 200 },
    required_items  => [
      {
        id       => 0,
        item     => { id => 'scrap-metal', icon => 'scrap.png', name => 'Scrap Metal', rarity => 'Common', item_type => 'Material' },
        item_id  => 'scrap-metal',
        quantity => 100,
      },
    ],
    rewards => [
      {
        id       => 0,
        item     => { id => 'xp-boost', icon => 'boost.png', name => 'XP Boost', rarity => 'rare', item_type => 'consumable' },
        item_id  => 'xp-boost',
        quantity => 3,
      },
    ],
  });

  is($quest->name, 'Upgrade Stash Capacity', 'name');
  is($quest->xp, 50, 'xp mapped');
  is($quest->created_at, '2024-01-01T00:00:00Z', 'created_at');
  is($quest->updated_at, '2024-01-02T00:00:00Z', 'updated_at');
  is($quest->locations->[0]{map}, 'dam', 'locations');
  is($quest->marker_category, 'side', 'marker_category');
  is($quest->image, 'https://example.com/stash.png', 'image');
  is($quest->guide_links->[0]{url}, 'https://guide.example.com/stash', 'guide_links');
  is($quest->guide_url, '/arc-raiders/upgrade-stash-capacity-arc-raiders', 'guide_url mapped');
  is($quest->trader_name, 'Trader Jane', 'trader_name');
  is($quest->sort_order, 5, 'sort_order');
  is($quest->position->{x}, 100, 'position x from hashref');
  is($quest->required_items->[0]{item}{name}, 'Scrap Metal', 'required_items mapped');
  is($quest->rewards->[0]{item}{name}, 'XP Boost', 'nested rewards item name from hashref');
  is($quest->rewards->[0]{quantity}, 3, 'rewards quantity from hashref');
  is($quest->granted_items->[0]{item}{name}, 'Small Stash', 'granted_items mapped');
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
  is($quest->guide_url, undef, 'guide_url defaults to undef');
};

# t/fixtures/quests.json is the unchanged live /quests?page=1 response
# (the first 40 of 123 quests).
my $response = decode_json( path("$FindBin::Bin/fixtures/quests.json")->slurp_raw );
my %quest = map { $_->{id} => WWW::MetaForge::ArcRaiders::Result::Quest->from_hashref($_) }
  @{ $response->{data} };

# integers stay integers: a string would encode as ["5"]
sub encoded { JSON::MaybeXS->new->encode([ $_[0] ]) }

subtest 'live quests fixture' => sub {
  is(scalar keys %quest, 40, 'all 40 quests of page 1 parse');
  is($response->{pagination}{total}, 123, 'fixture is page 1 of 123 quests');
  is($_->_raw->{id}, $_->id, 'id matches _raw for ' . $_->id) for values %quest;
};

subtest 'description' => sub {
  my $q = $quest{'a-bad-feeling'};
  like($q->description, qr/^Even the slightest change to ARC's behavior could spell disaster\./, 'starts as the API text');
  like($q->description, qr/disaster\.\r\n\r\nAnd that signal you heard\?/, 'paragraph break (CRLF, as the API sends it) is kept');
  is($q->description, $q->_raw->{description}, 'description is the description key');
  is($q->trader_name, 'Celeste', 'trader_name');
  is($q->guide_url, '/arc-raiders/a-bad-feeling-quest-arc-raiders', 'guide_url');
  is($q->xp, 0, 'xp');
  is($quest{'boarding-the-frigate'}->xp, 10000, 'xp of boarding-the-frigate');
};

subtest 'additional_rewards' => sub {
  is_deeply($quest{'a-bad-feeling'}->additional_rewards,
    [ { kind => 'currency', name => 'XP', quantity => 5000 } ],
    'currency reward');

  is_deeply($quest{'a-symbol-of-unification'}->additional_rewards, [
    { kind => 'cosmetic-option', name => 'Dusted Cream', quantity => 1,
      group => 'Aviator', setting => 'Color', included_with => 'Aviator' },
    { kind => 'cosmetic-option', name => 'On', quantity => 1,
      group => 'Aviator', setting => 'Headgear', included_with => 'Aviator' },
    { kind => 'currency', name => 'XP', quantity => 5000 },
  ], 'cosmetic options keep group, setting and included_with');

  is(scalar @{ $quest{'a-dead-end'}->additional_rewards }, 2, 'two currency rewards on a-dead-end');
  is_deeply($quest{'a-dead-end'}->additional_rewards, $quest{'a-dead-end'}->_raw->{additional_rewards},
    'additional_rewards is the additional_rewards key');
  ok(exists $quest{'a-bad-feeling'}->_raw->{additional_granted_items}, 'the unmodelled additional_granted_items stays in _raw');
};

subtest 'manifest' => sub {
  my $m = $quest{'a-bad-feeling'}->manifest;
  is(ref $m, 'HASH', 'manifest is a hashref');
  is($m->{cadence}, 'NARRATIVE', 'cadence');
  is($m->{objective_root}, 'objective-0', 'objective_root');
  is($m->{updated_at}, '2026-10-27T12:30:24.714+00:00', 'updated_at');
  is_deeply($m->{conditions}, [], 'conditions');
  is($m->{coverage}{objectiveCount}, 1, 'coverage objectiveCount');
  is($m->{objective_graph}[0]{description}, 'Find and search any ARC Probe or ARC Courier', 'objective_graph description');
  is($m->{objective_graph}[0]{action}{type}, 'Interact', 'objective_graph action type');
  is_deeply($m->{prerequisites},
    [ { quest_id => 'off-the-raider', name => 'Off The Radar', required_state => 'COMPLETED' } ],
    'prerequisites');
  is_deeply($m, $quest{'a-bad-feeling'}->_raw->{manifest}, 'manifest is the manifest key');

  is_deeply([ map { $_->{quest_id} } @{ $quest{'back-on-top'}->manifest->{prerequisites} } ],
    [qw( the-majors-footlocker eyes-in-the-sky celestes-journals )],
    'several prerequisites in API order');
  is($quest{'back-on-top'}->manifest->{prerequisites}[0]{name}, "The Major\x{2019}s Footlocker", 'prerequisite name keeps the typographic apostrophe');
  is($quest{'armored-transports'}->manifest->{prerequisites}[1]{required_state}, 'COMPLETED', 'required_state');
};

subtest 'items: id and quantity are integers' => sub {
  my $reward = $quest{'a-bad-feeling'}->rewards->[0];
  is($reward->{item}{name}, 'Metal Parts', 'reward item name');
  is($reward->{item_id}, 'metal-parts', 'reward item_id');
  is(encoded($reward->{quantity}), '[10]', 'rewards quantity is an integer (not a string)');
  is(encoded($reward->{id}), '[0]', 'rewards id is an integer');
  is(encoded($quest{'a-bad-feeling'}->rewards->[1]{id}), '[1]', 'second rewards id');
  is($quest{'a-bad-feeling'}->rewards->[1]{item}{name}, 'Steel Spring', 'second reward item name');

  my $after = $quest{'after-rain-comes'};
  is(scalar @{ $after->required_items }, 2, 'required_items count');
  is_deeply([ map { [ $_->{quantity}, $_->{item}{name} ] } @{ $after->required_items } ],
    [ [ 5, 'Wires' ], [ 2, 'Battery' ] ], 'required_items quantity and item name');
  is(encoded($after->required_items->[0]{quantity}), '[5]', 'required_items quantity is an integer');
  is(encoded($after->required_items->[0]{id}), '[0]', 'required_items id is an integer');
  is(scalar @{ $after->granted_items }, 1, 'granted_items count');
  is(encoded($after->granted_items->[0]{quantity}), '[' . $after->_raw->{granted_items}[0]{quantity} . ']', 'granted_items quantity is an integer');
  is_deeply($after->required_items, $after->_raw->{required_items}, 'required_items is the required_items key');
  is_deeply($after->granted_items, $after->_raw->{granted_items}, 'granted_items is the granted_items key');
  is_deeply($after->rewards, $after->_raw->{rewards}, 'rewards is the rewards key');
  is_deeply($after->manifest->{prerequisites}, [ { quest_id => 'eyes-in-the-sky', name => 'Eyes in the Sky', required_state => 'COMPLETED' } ], 'prerequisite of after-rain-comes');
};

subtest 'defaults for the new fields' => sub {
  my $quest = WWW::MetaForge::ArcRaiders::Result::Quest->from_hashref({ id => 'bare', name => 'Bare' });
  is($quest->description, undef, 'description is undef');
  is_deeply($quest->additional_rewards, [], 'additional_rewards defaults to []');
  is_deeply($quest->manifest, {}, 'manifest defaults to {}');
};

done_testing;