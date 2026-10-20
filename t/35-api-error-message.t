#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use HTTP::Response;

use_ok('WWW::MetaForge::ArcRaiders');
use_ok('WWW::MetaForge::GameMapData');

# A UA that answers every request with an API error.
package Stub::UA;
use strict;
use warnings;
use HTTP::Response;

sub new {
  my ($class, %args) = @_;
  return bless {
    status  => $args{status} // 400,
    message => $args{message} // 'Bad Request',
  }, $class;
}

sub request {
  my ($self, $http_request) = @_;

  my $response = HTTP::Response->new($self->{status}, $self->{message});
  $response->content('{"error":"invalid request"}');
  $response->header('Content-Type' => 'application/json');
  return $response;
}

package main;

subtest 'the ARC Raiders error names the method, the path and the query' => sub {
  my $api = WWW::MetaForge::ArcRaiders->new(ua => Stub::UA->new, use_cache => 0);

  my $error = do { local $@; eval { $api->items(search => 'Ferro') }; $@ };

  like($error, qr{API request failed: 400 Bad Request}, 'the message names the status');
  like($error, qr{\(GET /api/arc-raiders/items\?search=Ferro\)},
    'the message names the method, the path and the query');
  unlike($error, qr{metaforge\.app}, 'the message does not name the host');
};

subtest 'the Game Map Data error names the method, the path and the query' => sub {
  my $api = WWW::MetaForge::GameMapData->new(ua => Stub::UA->new, use_cache => 0);

  my $error = do { local $@; eval { $api->map_data(map => 'nonexistent') }; $@ };

  like($error, qr{API request failed: 400 Bad Request}, 'the message names the status');
  like($error, qr{\(GET /api/game-map-data\?[^)]*\)},
    'the message names the method and the path');
  like($error, qr{mapID=nonexistent}, 'the message names the parameter that was wrong');
  like($error, qr{tableID=arc_map_data}, 'the message names the table parameter');
  unlike($error, qr{metaforge\.app}, 'the message does not name the host');
};

done_testing;
