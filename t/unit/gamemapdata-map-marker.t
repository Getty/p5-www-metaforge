#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use WWW::MetaForge::GameMapData::Result::MapMarker;

subtest 'from_hashref with coordinates object' => sub {
  my $data = {
    id          => '1001',
    type        => 'Field Cache',
    name        => 'Loot Cache',
    description => 'Random loot chest',
    coordinates => { x => 123.5, y => 78.1 },
  };

  my $marker = WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref($data);

  is($marker->id, '1001', 'id');
  is($marker->type, 'Field Cache', 'type');
  is($marker->name, 'Loot Cache', 'name');
  is($marker->description, 'Random loot chest', 'description');
  is($marker->x, 123.5, 'x coordinate');
  is($marker->y, 78.1, 'y coordinate');
};

subtest 'from_hashref with position object' => sub {
  my $data = {
    id       => '1002',
    type     => 'POI',
    name     => 'Tower',
    position => { x => 50, y => 100, z => 25 },
  };

  my $marker = WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref($data);

  is($marker->x, 50, 'x from position');
  is($marker->y, 100, 'y from position');
  is($marker->z, 25, 'z from position');
};

subtest 'from_hashref with flat coordinates' => sub {
  my $data = {
    id   => '1003',
    type => 'Resource',
    name => 'Iron Node',
    x    => 200,
    y    => 300,
  };

  my $marker = WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref($data);

  is($marker->x, 200, 'x from flat');
  is($marker->y, 300, 'y from flat');
};

subtest 'coordinates method' => sub {
  my $marker = WWW::MetaForge::GameMapData::Result::MapMarker->new(
    id => '1',
    x  => 10,
    y  => 20,
    _raw => {},
  );

  my $coords = $marker->coordinates;
  is_deeply($coords, { x => 10, y => 20 }, 'coordinates without z');

  my $marker_z = WWW::MetaForge::GameMapData::Result::MapMarker->new(
    id => '2',
    x  => 10,
    y  => 20,
    z  => 5,
    _raw => {},
  );

  my $coords_z = $marker_z->coordinates;
  is_deeply($coords_z, { x => 10, y => 20, z => 5 }, 'coordinates with z');
};

subtest 'alternative field names' => sub {
  my $data = {
    id       => '1004',
    category => 'Quest',
    title    => 'Quest Location',
    image    => 'quest.png',
    updated_at => '2025-01-01T00:00:00Z',
    x => 100, y => 200,
  };

  my $marker = WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref($data);

  is($marker->type, 'Quest', 'category -> type');
  is($marker->name, 'Quest Location', 'title -> name');
  is($marker->icon, 'quest.png', 'image -> icon');
  is($marker->last_updated, '2025-01-01T00:00:00Z', 'updated_at -> last_updated');
};

subtest '_raw preserved' => sub {
  my $data = {
    id            => '1005',
    type          => 'Test',
    custom_field  => 'custom_value',
    x => 100, y => 200,
  };

  my $marker = WWW::MetaForge::GameMapData::Result::MapMarker->from_hashref($data);

  is($marker->_raw->{custom_field}, 'custom_value', '_raw contains original data');
};

done_testing;
