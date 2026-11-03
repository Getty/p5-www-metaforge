#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use JSON::MaybeXS qw( decode_json is_bool );
use Path::Tiny;

use_ok('WWW::MetaForge::ArcRaiders::Result::Arc');

subtest 'constructor' => sub {
  my $arc = WWW::MetaForge::ArcRaiders::Result::Arc->new(
    id          => 'cold-snap',
    name        => 'Cold Snap',
    description => 'A sudden cold front.',
    icon        => 'https://metaforge.app/icons/cold-snap.png',
    image       => 'https://metaforge.app/images/cold-snap.jpg',
    created_at  => '2024-01-15T10:00:00Z',
    updated_at  => '2024-01-20T12:30:00Z',
    _raw        => {},
  );

  is($arc->id, 'cold-snap', 'id');
  is($arc->name, 'Cold Snap', 'name');
  is($arc->description, 'A sudden cold front.', 'description');
  is($arc->icon, 'https://metaforge.app/icons/cold-snap.png', 'icon');
  is($arc->image, 'https://metaforge.app/images/cold-snap.jpg', 'image');
  is($arc->created_at, '2024-01-15T10:00:00Z', 'created_at');
  is($arc->updated_at, '2024-01-20T12:30:00Z', 'updated_at');
};

subtest 'from_hashref passthrough' => sub {
  my $data = {
    id          => 'harvester',
    name        => 'Harvester',
    description => 'Harvest event.',
    icon        => 'harvester-icon',
    image       => 'harvester-img',
    created_at  => '2024-02-01T08:00:00Z',
    updated_at  => '2024-02-10T14:00:00Z',
  };

  my $arc = WWW::MetaForge::ArcRaiders::Result::Arc->from_hashref($data);

  is($arc->id, 'harvester', 'id from hashref');
  is($arc->name, 'Harvester', 'name from hashref');
  is($arc->description, 'Harvest event.', 'description from hashref');
  is($arc->icon, 'harvester-icon', 'icon from hashref');
  is($arc->image, 'harvester-img', 'image from hashref');
  is($arc->created_at, '2024-02-01T08:00:00Z', 'created_at from hashref');
  is($arc->updated_at, '2024-02-10T14:00:00Z', 'updated_at from hashref');
  is($arc->_raw, $data, '_raw holds original data');
};

subtest 'minimal arc' => sub {
  my $arc = WWW::MetaForge::ArcRaiders::Result::Arc->from_hashref({
    id   => 'minimal',
    name => 'Minimal Arc',
  });

  is($arc->id, 'minimal', 'id');
  is($arc->name, 'Minimal Arc', 'name');
  is($arc->description, undef, 'description is undef');
  is($arc->icon, undef, 'icon is undef');
  is($arc->image, undef, 'image is undef');
  is($arc->created_at, undef, 'created_at is undef');
  is($arc->updated_at, undef, 'updated_at is undef');
};

# t/fixtures/arcs.json is the unchanged live /arcs?includeLoot=true response
# (26 arcs, all of them).
my $response = decode_json( path("$FindBin::Bin/fixtures/arcs.json")->slurp_raw );
my %arc = map { $_->{id} => WWW::MetaForge::ArcRaiders::Result::Arc->from_hashref($_) }
  @{ $response->{data} };

subtest 'live arcs fixture' => sub {
  is(scalar keys %arc, 26, 'all 26 arcs parse');
  is($response->{pagination}{total}, 26, 'fixture holds the whole inventory');
  is($_->_raw->{id}, $_->id, 'id matches _raw for ' . $_->id) for values %arc;
};

subtest 'fields of a live arc' => sub {
  my $rollbot = $arc{rollbot};
  is($rollbot->name, 'ARC Surveyor', 'name');
  is($rollbot->icon, 'https://unhbvkszwhczbjxgetgk.supabase.co/storage/v1/object/public/images/arc-raiders/icons/rollbot.webp', 'icon');
  is($rollbot->image, 'https://static.metaforge.app/arc-raiders/images/rollbot.webp', 'image');
  is($rollbot->created_at, '2025-10-08T11:32:47.592365+00:00', 'created_at');
  is($rollbot->updated_at, '2026-09-30T08:36:05.77825+00:00', 'updated_at');
  like($rollbot->description, qr/^This is the largest of the rolling ARCs/, 'description');
  is($rollbot->_raw->{guide_url}, undef, 'guide_url is always null live (not modelled)');
  ok(!$rollbot->can('guide_url'), 'no guide_url attribute');
};

subtest 'data (variants)' => sub {
  my $rollbot = $arc{rollbot};
  is(ref $rollbot->data, 'HASH', 'data is a hashref');
  is($rollbot->data->{updated_at}, '2026-09-20T19:16:18.001037+00:00', 'data updated_at');
  is(scalar @{ $rollbot->data->{variants} }, 1, 'one variant');
  ok(is_bool($rollbot->data->{variants}[0]{can_fly}), 'can_fly is a JSON boolean');
  ok(!$rollbot->data->{variants}[0]{can_fly}, 'rollbot cannot fly');

  ok($arc{firefly}->data->{variants}[0]{can_fly}, 'firefly can fly');
  ok($arc{hornet}->data->{variants}[0]{can_fly}, 'hornet can fly');
  is_deeply($arc{firefly}->data, $arc{firefly}->_raw->{data}, 'data is the data key of the record');

  my @with_data = grep { %{ $_->data } } values %arc;
  is(scalar @with_data, 21, '21 of 26 arcs carry data');
  for my $id (qw( arc-assessor frigate bully hydra skulker )) {
    is_deeply($arc{$id}->data, {}, "$id has no data key: data defaults to {}");
    ok(!exists $arc{$id}->_raw->{data}, "$id: _raw really has no data key");
  }
};

subtest 'loot (includeLoot=true)' => sub {
  my $rollbot = $arc{rollbot};
  is(scalar @{ $rollbot->loot }, 14, 'rollbot has 14 drops');
  is($rollbot->loot->[0]{item}{name}, 'ARC Alloy', 'first drop item name');
  is($rollbot->loot->[0]{item}{rarity}, 'Uncommon', 'first drop item rarity');
  is($rollbot->loot->[0]{item_id}, 'arc-alloy', 'first drop item_id');
  is($arc{'arc-assessor'}->loot->[0]{item}{id}, 'arc-powercell', 'arc-assessor first drop');
  is(scalar @{ $arc{frigate}->loot }, 0, 'frigate has an empty loot list');
};

subtest 'without includeLoot the record has no loot key' => sub {
  my %raw = %{ $response->{data}[0] };
  delete $raw{loot};
  my $arc = WWW::MetaForge::ArcRaiders::Result::Arc->from_hashref(\%raw);
  is_deeply($arc->loot, [], 'loot defaults to []');
};

done_testing;