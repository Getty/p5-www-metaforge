#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

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

done_testing;