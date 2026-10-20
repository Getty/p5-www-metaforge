#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use HTTP::Response;

use_ok('WWW::MetaForge::ArcRaiders');

# A UA that always answers with a next page, the way a broken API would.
# MockUA cannot serve that: it ends the pagination on page 2.
package Stub::UA;
use strict;
use warnings;
use HTTP::Response;

sub new {
  my ($class, %args) = @_;
  return bless {
    requests      => 0,
    has_next_page => $args{has_next_page} // 1,
  }, $class;
}

sub requests { return $_[0]->{requests} }

sub request {
  my ($self, $http_request) = @_;
  $self->{requests}++;

  my $response = HTTP::Response->new(200, 'OK');
  $response->content(
    '{"data":[{"id":"ferro-i","name":"Ferro I"}],'
      . '"pagination":{"page":1,"total":9999,"totalPages":9999,"hasNextPage":'
      . ($self->{has_next_page} ? 'true' : 'false')
      . '}}'
  );
  $response->header('Content-Type' => 'application/json');
  return $response;
}

package main;

subtest 'max_pages defaults to 100' => sub {
  my $api = WWW::MetaForge::ArcRaiders->new(ua => Stub::UA->new, use_cache => 0);
  can_ok($api, 'max_pages');
  is($api->can('max_pages') ? $api->max_pages : 'no max_pages', 100,
    'the default page limit is 100');
};

subtest 'the pagination stops at the page limit' => sub {
  my $ua = Stub::UA->new;
  my $api = WWW::MetaForge::ArcRaiders->new(
    ua        => $ua,
    use_cache => 0,
    max_pages => 3,
  );

  my @warnings;
  local $SIG{__WARN__} = sub { push @warnings, $_[0] };

  # The alarm keeps the test from hanging when the pagination does not stop.
  local $SIG{ALRM} = sub { die "the pagination did not stop at the limit\n" };
  alarm 5;
  my $items = eval { $api->items_all };
  my $error = $@;
  alarm 0;

  if ($error) {
    fail("the pagination did not stop at the limit: $error");
    return;
  }

  is($ua->requests, 3, 'the client made exactly max_pages requests');
  is(scalar @$items, 3, 'the data of every page is in the result');
  like(
    $warnings[0] // '',
    qr/\Qthe pagination stopped after 3 pages, the answer may be incomplete\E/,
    'the client warns that the answer may be incomplete'
  );
};

subtest 'a pagination that ends does not warn' => sub {
  my $ua = Stub::UA->new(has_next_page => 0);
  my $api = WWW::MetaForge::ArcRaiders->new(
    ua        => $ua,
    use_cache => 0,
    max_pages => 3,
  );

  my @warnings;
  local $SIG{__WARN__} = sub { push @warnings, $_[0] };
  my $items = $api->items_all;

  is($ua->requests, 1, 'the client made one request');
  is(scalar @$items, 1, 'the result holds one page of data');
  is(scalar @warnings, 0, 'no warning about an incomplete answer');
};

done_testing;
