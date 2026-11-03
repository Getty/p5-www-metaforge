package MockUA;
use strict;
use warnings;
use Path::Tiny;
use HTTP::Response;
use LWP::UserAgent;
use URI;
use Encode;
use JSON::MaybeXS;

# Network lock: the default suite never talks to the network. Loading MockUA
# (without WWW_METAFORGE_USE_LIVE_API) makes any real LWP::UserAgent request
# die loudly with the URL, so a test that bypasses the mock cannot pass by
# accident (or hang on a slow API).
unless ($ENV{WWW_METAFORGE_USE_LIVE_API}) {
  no warnings 'redefine';
  for my $method (qw(request simple_request)) {
    no strict 'refs';
    *{"LWP::UserAgent::$method"} = sub {
      my ($self, $http_request) = @_;
      my $target = ref $http_request && $http_request->can('uri')
        ? $http_request->method . ' ' . $http_request->uri
        : '(unknown request)';
      die "MockUA: network access blocked in the offline suite: $target\n";
    };
  }
}

# What this mock simplifies compared to the live API:
#  - fixtures are byte-faithful live responses; the mock only selects,
#    gates or filters what it serves, it never edits the files
#  - /items: page 1 is t/fixtures/items.json, page N is
#    t/fixtures/items-page-N.json when that file exists, otherwise an
#    empty page (data [], pagination consistent with the page-1 totals), so a
#    walk over all pages ends after totalPages with the pages on disk
#  - /items item_type and rarity filter the page-1 fixture exactly and
#    case-sensitively (AND); the result is one page, pagination recomputed
#    (total, totalPages 0 or 1, no next page). Other parameters (search,
#    limit, ...) are not evaluated.
#  - /events-schedule serves t/fixtures/events-schedule.json (region europe)
#    whatever the query, except region=all: that serves the byte-faithful
#    t/fixtures/events-schedule-region-all.json (5 regions, every record
#    carries its region). Any other region value is not evaluated (the live
#    API answers an unknown region with europe); map and name are not either
#  - /hideout and /weekly-trials serve t/fixtures/hideout.json and
#    t/fixtures/weekly-trials.json verbatim; both endpoints take no
#    parameters, a query string changes nothing. The weekly-trials
#    fixture is a snapshot: its window boundaries (activeWindowEnd,
#    nextWindowStart) lie in the past once that moment has passed.
#  - /quests with an id that no record of t/fixtures/quests.json carries
#    answers 404 Not Found, body {"error":"Quest not found"} (live, curl,
#    2026-11-03: quests?id=celestes-journals is 200, quests?id=<unknown> is
#    404; items?id and arcs?id with an unknown id stay 200 with empty data,
#    so only quests are gated). A mock that answered every id with 200 would
#    hide the 404 from the offline suite. A known id serves the fixture;
#    RecordingUA (and with it OfflineLWP, the bin subprocess) sits on top
#    of this mock, so the 404 holds there too.
#  - every request is recorded, see requests()

my @ITEM_RELATIONS = qw(
  components dropped_by mods recycle_components recycle_from
  relationships sold_by used_in
);

sub new {
  my ($class, %args) = @_;
  return bless {
    fixtures_dir => $args{fixtures_dir} // 't/fixtures',
    requests     => [],
  }, $class;
}

# URIs (strings) of all requests this UA has answered, in order
sub requests { return @{ $_[0]{requests} } }
sub last_request { return $_[0]{requests}[-1] }

sub _query {
  my ($self, $uri) = @_;
  my @pairs = URI->new($uri)->query_form;
  my %query;
  while (my ($key, $value) = splice @pairs, 0, 2) { $query{$key} = $value }
  return %query;
}

sub _json { return JSON::MaybeXS->new(canonical => 1) }

sub _response {
  my ($self, $content) = @_;
  my $response = HTTP::Response->new(200, 'OK');
  $response->content(Encode::encode('UTF-8', $content));
  $response->header('Content-Type' => 'application/json');
  return $response;
}

sub _items_response {
  my ($self, $uri) = @_;
  my %query = $self->_query($uri);
  my $page  = defined $query{page} && $query{page} =~ /^\d+$/ ? int($query{page}) : 1;
  my $dir   = path($self->{fixtures_dir});
  my $first = $dir->child('items.json');
  return HTTP::Response->new(404, 'Fixture not found: items.json') unless $first->is_file;

  my $envelope = $self->_json->decode($first->slurp_utf8);
  my $filtered = grep { defined $query{$_} } qw(item_type rarity);
  my $content;

  if ($filtered) {
    my @rows = grep {
      my $row = $_;
      !grep { defined $query{$_} && !(defined $row->{$_} && $row->{$_} eq $query{$_}) } qw(item_type rarity)
    } @{ $envelope->{data} };
    my $total = scalar @rows;
    $envelope->{data} = $page == 1 ? \@rows : [];
    $envelope->{pagination} = {
      page        => $page,
      limit       => $query{limit} ? int($query{limit}) : $envelope->{pagination}{limit},
      total       => $total,
      totalPages  => $total ? 1 : 0,
      hasNextPage => \0,
      hasPrevPage => $page > 1 ? \1 : \0,
    };
  } elsif ($page > 1) {
    my $file = $dir->child("items-page-$page.json");
    if ($file->is_file) {
      $envelope = $self->_json->decode($file->slurp_utf8);
    } else {
      my $total_pages = $envelope->{pagination}{totalPages};
      $envelope->{data} = [];
      $envelope->{pagination}{page}        = $page;
      $envelope->{pagination}{hasNextPage} = $page < $total_pages ? \1 : \0;
      $envelope->{pagination}{hasPrevPage} = \1;
    }
  }

  # Query-param gating: without includeComponents=true the live API leaves
  # the relation keys out altogether (they are not empty, they are absent).
  if (($query{includeComponents} // '') ne 'true') {
    for my $row (grep { ref eq 'HASH' } @{ $envelope->{data} }) {
      delete @{$row}{@ITEM_RELATIONS};
    }
  }

  # Unfiltered page 1 is served verbatim (the bytes of the fixture file).
  $content = !$filtered && $page == 1 && ($query{includeComponents} // '') eq 'true'
    ? $first->slurp_utf8
    : $self->_json->encode($envelope);
  return $self->_response($content);
}

sub request {
  my ($self, $http_request) = @_;
  my $uri = $http_request->uri;
  push @{ $self->{requests} }, "$uri";

  return $self->_items_response($uri) if $uri =~ m{/api/arc-raiders/items\b};

  my $fixture_file;
  if ($uri =~ /\/traders/) {
    $fixture_file = 'traders.json';
  } elsif ($uri =~ /\/quests/) {
    $fixture_file = 'quests.json';
  } elsif ($uri =~ /\/events-schedule/) {
    $fixture_file = $uri =~ /[?&]region=all(?:&|$)/
      ? 'events-schedule-region-all.json'
      : 'events-schedule.json';
  } elsif ($uri =~ m{/hideout\b}) {
    $fixture_file = 'hideout.json';
  } elsif ($uri =~ m{/weekly-trials\b}) {
    $fixture_file = 'weekly-trials.json';
  } elsif ($uri =~ /\/arcs/) {
    $fixture_file = 'arcs.json';
  } elsif ($uri =~ /game-map-data/) {
    # Extract mapID from query string
    my ($map) = $uri =~ /mapID=([^&]+)/;
    $fixture_file = $map ? "map-data-$map.json" : 'map-data.json';
  } else {
    return HTTP::Response->new(404, 'Not Found');
  }

  my $file = path($self->{fixtures_dir}, $fixture_file);

  if ($fixture_file eq 'quests.json' && $file->is_file) {
    my %query = $self->_query($uri);
    if (defined $query{id}) {
      my $decoded = $self->_json->decode($file->slurp_utf8);
      unless (grep { ($_->{id} // '') eq $query{id} } @{ $decoded->{data} }) {
        my $response = HTTP::Response->new(404, 'Not Found');
        $response->content('{"error":"Quest not found"}');
        $response->header('Content-Type' => 'application/json');
        return $response;
      }
    }
  }

  unless ($file->is_file) {
    return HTTP::Response->new(404, 'Fixture not found: ' . $fixture_file);
  }

  my $content = $file->slurp_utf8;

  # Page-aware pagination: fixtures are byte-faithful "page 1" responses that
  # report hasNextPage=true. _fetch_all_pages walks page=2,3,... until
  # hasNextPage goes false, so an endpoint that always returned page 1 would
  # loop forever. Honour the page query param: page 1 (or none) serves the
  # fixture verbatim; any later page is a synthesized terminal page with an
  # empty data set and hasNextPage=false, so multi-page fetches terminate
  # offline without hand-editing the byte-faithful fixture.
  my ($page) = $uri =~ /[?&]page=(\d+)/;
  if (defined $page && $page > 1) {
    my $decoded = eval { JSON::MaybeXS->new->decode($content) };
    if (ref $decoded eq 'HASH' && ref $decoded->{pagination} eq 'HASH') {
      $decoded->{data} = [];
      $decoded->{pagination}{page}        = int($page);
      $decoded->{pagination}{hasNextPage} = \0;
      $decoded->{pagination}{hasPrevPage} = \1;
      $content = JSON::MaybeXS->new->encode($decoded);
    }
  }

  # Query-param gating for /arcs: the live API only sends the loot relation
  # with includeLoot=true. The fixture is captured with the flag set, so
  # without it the key is removed.
  if ($fixture_file eq 'arcs.json' && $uri !~ /[?&]includeLoot=true\b/) {
    my $decoded = eval { JSON::MaybeXS->new->decode($content) };
    if (ref $decoded eq 'HASH' && ref $decoded->{data} eq 'ARRAY') {
      delete $_->{loot} for grep { ref eq 'HASH' } @{$decoded->{data}};
      $content = JSON::MaybeXS->new->encode($decoded);
    }
  }

  return $self->_response($content);
}

1;
