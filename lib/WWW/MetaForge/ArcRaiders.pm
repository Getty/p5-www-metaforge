package WWW::MetaForge::ArcRaiders;
# ABSTRACT: Perl client for the MetaForge ARC Raiders API

use Moo;
use LWP::UserAgent;
use JSON::MaybeXS;
use Carp qw(croak);
use namespace::clean;

our $DEBUG = $ENV{WWW_METAFORGE_ARCRAIDERS_DEBUG};

use WWW::MetaForge::Cache;
use WWW::MetaForge::GameMapData;
use WWW::MetaForge::ArcRaiders::Request;
use WWW::MetaForge::ArcRaiders::Result::Item;
use WWW::MetaForge::ArcRaiders::Result::Arc;
use WWW::MetaForge::ArcRaiders::Result::Quest;
use WWW::MetaForge::ArcRaiders::Result::Trader;
use WWW::MetaForge::ArcRaiders::Result::EventTimer;
use WWW::MetaForge::ArcRaiders::Result::MapMarker;

# Fixed list of ARC Raiders maps (API mapID format)
our @MAPS = qw(dam spaceport buried-city blue-gate stella-montis);
our %MAP_DISPLAY_NAMES = (
  'dam'           => 'Dam',
  'spaceport'     => 'Spaceport',
  'buried-city'   => 'Buried City',
  'blue-gate'     => 'Blue Gate',
  'stella-montis' => 'Stella Montis',
);

sub maps { return @MAPS }
sub map_display_names { return %MAP_DISPLAY_NAMES }
sub map_display_name {
  my ($self, $map_id) = @_;
  return $MAP_DISPLAY_NAMES{$map_id} // $map_id;
}

has ua => (
  is      => 'ro',
  lazy    => 1,
  builder => '_build_ua',
);

has request => (
  is      => 'ro',
  lazy    => 1,
  default => sub { WWW::MetaForge::ArcRaiders::Request->new },
);

has cache => (
  is      => 'ro',
  lazy    => 1,
  builder => '_build_cache',
);

has use_cache => (
  is      => 'ro',
  default => 1,
);

has cache_dir => (
  is => 'ro',
);

has json => (
  is      => 'ro',
  lazy    => 1,
  default => sub { JSON::MaybeXS->new(utf8 => 1) },
);

has debug => (
  is      => 'ro',
  default => sub { $DEBUG },
);

sub _debug {
  my ($self, $msg) = @_;
  return unless $self->debug;
  my $ts = localtime;
  warn "[WWW::MetaForge::ArcRaiders $ts] $msg\n";
}

sub _build_ua {
  my ($self) = @_;
  my $ua = LWP::UserAgent->new(
    agent   => 'WWW-MetaForge-ArcRaiders/' . ($WWW::MetaForge::ArcRaiders::VERSION // 'dev'),
    timeout => 30,
  );
  return $ua;
}

sub _build_cache {
  my ($self) = @_;
  my %args;
  $args{cache_dir} = $self->cache_dir if defined $self->cache_dir;
  return WWW::MetaForge::Cache->new(%args);
}

has game_map_data => (
  is      => 'ro',
  lazy    => 1,
  builder => '_build_game_map_data',
);

sub _build_game_map_data {
  my ($self) = @_;
  return WWW::MetaForge::GameMapData->new(
    debug        => $self->debug,
    use_cache    => $self->use_cache,
    cache        => $self->cache,  # Share cache with ArcRaiders
    marker_class => 'WWW::MetaForge::ArcRaiders::Result::MapMarker',
  );
}

sub _fetch {
  my ($self, $endpoint, $http_request, %params) = @_;

  my $skip_cache = delete $params{_skip_cache};

  if ($self->use_cache && !$skip_cache) {
    my $cached = $self->cache->get($endpoint, \%params);
    if (defined $cached) {
      $self->_debug("CACHE HIT: $endpoint");
      return $cached;
    }
    $self->_debug("CACHE MISS: $endpoint");
  }

  my $url = $http_request->uri;
  $self->_debug("REQUEST: GET $url");

  my $response = $self->ua->request($http_request);

  $self->_debug("RESPONSE: " . $response->code . " " . $response->message);

  unless ($response->is_success) {
    croak sprintf("API request failed: %s %s",
      $response->code, $response->message);
  }

  my $data = eval { $self->json->decode($response->decoded_content) };
  croak "Failed to parse JSON response: $@" if $@;

  my $count = ref $data eq 'ARRAY' ? scalar(@$data) : 1;
  $self->_debug("PARSED: $count records");

  if ($self->use_cache && !$skip_cache) {
    $self->cache->set($endpoint, \%params, $data);
    $self->_debug("CACHE SET: $endpoint");
  }

  return $data;
}

sub _extract_data {
  my ($self, $response) = @_;

  return $response unless ref $response eq 'HASH';

  # API returns {"data": ...} or {"success": true, "data": ...}
  if (exists $response->{data}) {
    return $response->{data};
  }

  return $response;
}

sub _to_objects {
  my ($self, $data, $class) = @_;

  return [] unless defined $data;

  if (ref $data eq 'ARRAY') {
    return [ map { $class->from_hashref($_) } @$data ];
  } elsif (ref $data eq 'HASH') {
    return $class->from_hashref($data);
  }

  return $data;
}

# Generic paginated fetch - returns {data => [...], pagination => {...}}
sub _fetch_paginated {
  my ($self, $endpoint, $request_method, $result_class, %params) = @_;

  my $req = $self->request->$request_method(%params);
  my $response = $self->_fetch($endpoint, $req, %params);
  my $data = $self->_extract_data($response);
  my $pagination = ref $response eq 'HASH' ? $response->{pagination} : undef;

  return {
    data       => $self->_to_objects($data, $result_class),
    pagination => $pagination,
  };
}

# Fetch all pages for a paginated endpoint
sub _fetch_all_pages {
  my ($self, $endpoint, $request_method, $result_class, %params) = @_;

  my @all_data;
  my $current_page = 1;

  while (1) {
    $params{page} = $current_page;
    my $result = $self->_fetch_paginated($endpoint, $request_method, $result_class, %params);
    push @all_data, @{$result->{data}};

    my $pagination = $result->{pagination};
    last unless $pagination && $pagination->{hasNextPage};
    $current_page++;
  }

  return \@all_data;
}

sub items {
  my ($self, %params) = @_;
  return $self->_fetch_paginated('items', 'items', 'WWW::MetaForge::ArcRaiders::Result::Item', %params)->{data};
}

sub items_paginated {
  my ($self, %params) = @_;
  return $self->_fetch_paginated('items', 'items', 'WWW::MetaForge::ArcRaiders::Result::Item', %params);
}

sub items_all {
  my ($self, %params) = @_;
  return $self->_fetch_all_pages('items', 'items', 'WWW::MetaForge::ArcRaiders::Result::Item', %params);
}

# Legacy alias
sub items_with_pagination { shift->items_paginated(@_) }

sub arcs {
  my ($self, %params) = @_;
  return $self->_fetch_paginated('arcs', 'arcs', 'WWW::MetaForge::ArcRaiders::Result::Arc', %params)->{data};
}

sub arcs_paginated {
  my ($self, %params) = @_;
  return $self->_fetch_paginated('arcs', 'arcs', 'WWW::MetaForge::ArcRaiders::Result::Arc', %params);
}

sub arcs_all {
  my ($self, %params) = @_;
  return $self->_fetch_all_pages('arcs', 'arcs', 'WWW::MetaForge::ArcRaiders::Result::Arc', %params);
}

sub quests {
  my ($self, %params) = @_;
  return $self->_fetch_paginated('quests', 'quests', 'WWW::MetaForge::ArcRaiders::Result::Quest', %params)->{data};
}

sub quests_paginated {
  my ($self, %params) = @_;
  return $self->_fetch_paginated('quests', 'quests', 'WWW::MetaForge::ArcRaiders::Result::Quest', %params);
}

sub quests_all {
  my ($self, %params) = @_;
  return $self->_fetch_all_pages('quests', 'quests', 'WWW::MetaForge::ArcRaiders::Result::Quest', %params);
}

# Legacy alias
sub quests_with_pagination {
  my ($self, %params) = @_;
  my $result = $self->quests_paginated(%params);
  return { quests => $result->{data}, pagination => $result->{pagination} };
}

sub traders {
  my ($self, %params) = @_;
  my $req = $self->request->traders(%params);
  my $response = $self->_fetch('traders', $req, %params);
  my $data = $self->_extract_data($response);

  # Traders API returns {"TraderName": [...items...], ...}
  # Convert to array of trader objects
  if (ref $data eq 'HASH' && !exists $data->{id}) {
    my @traders;
    for my $name (sort keys %$data) {
      push @traders, WWW::MetaForge::ArcRaiders::Result::Trader->new(
        name      => $name,
        inventory => $data->{$name},
        _raw      => { name => $name, inventory => $data->{$name} },
      );
    }
    return \@traders;
  }

  return $self->_to_objects($data, 'WWW::MetaForge::ArcRaiders::Result::Trader');
}

# event_timers: always fresh (no cache) - time-critical data
sub event_timers {
  my ($self, %params) = @_;
  my $req = $self->request->event_timers(%params);
  my $response = $self->_fetch('event_timers', $req, %params, _skip_cache => 1);
  my $data = $self->_extract_data($response);
  return $self->_to_objects($data, 'WWW::MetaForge::ArcRaiders::Result::EventTimer');
}

# event_timers_cached: use cache (for when you don't need live data)
sub event_timers_cached {
  my ($self, %params) = @_;
  my $req = $self->request->event_timers(%params);
  my $response = $self->_fetch('event_timers', $req, %params);
  my $data = $self->_extract_data($response);
  return $self->_to_objects($data, 'WWW::MetaForge::ArcRaiders::Result::EventTimer');
}

sub map_data {
  my ($self, %params) = @_;
  return $self->game_map_data->map_data(%params);
}

sub items_raw {
  my ($self, %params) = @_;
  my $req = $self->request->items(%params);
  return $self->_fetch('items', $req, %params);
}

sub arcs_raw {
  my ($self, %params) = @_;
  my $req = $self->request->arcs(%params);
  return $self->_fetch('arcs', $req, %params);
}

sub quests_raw {
  my ($self, %params) = @_;
  my $req = $self->request->quests(%params);
  return $self->_fetch('quests', $req, %params);
}

sub traders_raw {
  my ($self, %params) = @_;
  my $req = $self->request->traders(%params);
  return $self->_fetch('traders', $req, %params);
}

sub event_timers_raw {
  my ($self, %params) = @_;
  my $req = $self->request->event_timers(%params);
  return $self->_fetch('event_timers', $req, %params);
}

sub map_data_raw {
  my ($self, %params) = @_;
  return $self->game_map_data->map_data_raw(%params);
}

sub clear_cache {
  my ($self, $endpoint) = @_;
  $self->cache->clear($endpoint);
}

1;

=head1 SYNOPSIS

  use WWW::MetaForge::ArcRaiders;

  my $api = WWW::MetaForge::ArcRaiders->new;

  # Get items
  my $items = $api->items;
  for my $item (@$items) {
      say $item->name . " (" . $item->rarity . ")";
  }

  # Search with parameters
  my $ferro = $api->items(search => 'Ferro');

  # Event timers with helper methods
  my $events = $api->event_timers;
  for my $event (@$events) {
      say $event->name;
      say "  Active!" if $event->is_active_now;
  }

  # Disable caching
  my $api = WWW::MetaForge::ArcRaiders->new(use_cache => 0);

  # For async usage (e.g., with WWW::Chain)
  my $request = $api->request->items(search => 'Ferro');

=head1 DESCRIPTION

Perl interface to the MetaForge ARC Raiders API for game data
(items, ARCs, quests, traders, event timers, map data).

=attr ua

L<LWP::UserAgent> instance. Built lazily with sensible defaults.

=attr request

L<WWW::MetaForge::ArcRaiders::Request> instance for creating
L<HTTP::Request> objects. Use for async framework integration.

=attr cache

L<WWW::MetaForge::Cache> instance for response caching.

=attr use_cache

Boolean, default true. Set to false to disable caching.

=attr cache_dir

Optional L<Path::Tiny> path for cache directory. Defaults to
XDG cache dir on Unix, LOCALAPPDATA on Windows.

=attr debug

Boolean. Enable debug output. Also settable via
C<$ENV{WWW_METAFORGE_ARCRAIDERS_DEBUG}>.

=attr game_map_data

L<WWW::MetaForge::GameMapData> instance used for C<map_data> calls.
Configured automatically with ARC Raiders specific marker class.

=method items

  my $items = $api->items(%params);

Returns ArrayRef of L<WWW::MetaForge::ArcRaiders::Result::Item>.
Supports C<search>, C<page>, C<limit> parameters.

=method arcs

  my $arcs = $api->arcs(%params);

Returns ArrayRef of L<WWW::MetaForge::ArcRaiders::Result::Arc>.
Supports C<includeLoot> parameter.

=method quests

  my $quests = $api->quests(%params);

Returns ArrayRef of L<WWW::MetaForge::ArcRaiders::Result::Quest>.
Supports C<type> parameter.

=method traders

  my $traders = $api->traders(%params);

Returns ArrayRef of L<WWW::MetaForge::ArcRaiders::Result::Trader>.

=method event_timers

  my $events = $api->event_timers(%params);

Returns ArrayRef of L<WWW::MetaForge::ArcRaiders::Result::EventTimer>.

=method map_data

  my $markers = $api->map_data(%params);

Returns ArrayRef of L<WWW::MetaForge::ArcRaiders::Result::MapMarker>.
Supports C<map> parameter.

=method items_raw

=method arcs_raw

=method quests_raw

=method traders_raw

=method event_timers_raw

=method map_data_raw

Same as above but return raw HashRef/ArrayRef instead of result objects.

=method clear_cache

  $api->clear_cache('items');  # Clear specific endpoint
  $api->clear_cache;           # Clear all

Clear cached responses.

=head1 ATTRIBUTION

This module uses the MetaForge API: L<https://metaforge.app>

=cut
