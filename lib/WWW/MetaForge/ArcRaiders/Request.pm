package WWW::MetaForge::ArcRaiders::Request;
# ABSTRACT: HTTP Request factory for MetaForge ARC Raiders API
our $VERSION = '0.003';

use Moo;
use HTTP::Request;
use URI;
use namespace::clean;

=head1 SYNOPSIS

    use WWW::MetaForge::ArcRaiders::Request;

    my $factory = WWW::MetaForge::ArcRaiders::Request->new;

    # Get HTTP::Request objects for async usage
    my $req = $factory->items(search => 'Ferro');
    my $req = $factory->event_timers(map => 'Dam');

=head1 DESCRIPTION

Factory for creating L<HTTP::Request> objects for the MetaForge API.
Use standalone for integration with async HTTP frameworks like L<WWW::Chain>.

=cut

our $BASE_URL = 'https://metaforge.app/api/arc-raiders';
our $MAP_DATA_URL = 'https://metaforge.app/api/game-map-data';

has base_url => (
  is      => 'ro',
  default => sub { $BASE_URL },
);

=attr base_url

Base URL for main API endpoints. Defaults to C<https://metaforge.app/api/arc-raiders>.

=cut

has map_data_url => (
  is      => 'ro',
  default => sub { $MAP_DATA_URL },
);

=attr map_data_url

Base URL for map data endpoint. Defaults to C<https://metaforge.app/api/game-map-data>.

=cut

sub _build_request {
  my ($self, $url, %params) = @_;
  my $uri = URI->new($url);
  $uri->query_form(%params) if %params;
  return HTTP::Request->new(GET => $uri->as_string);
}

sub items {
  my ($self, %params) = @_;
  return $self->_build_request($self->base_url . '/items', %params);
}

=method items

    my $req = $factory->items(search => 'Ferro', page => 1);

Returns L<HTTP::Request> for C</items> endpoint.

=cut

sub arcs {
  my ($self, %params) = @_;
  return $self->_build_request($self->base_url . '/arcs', %params);
}

=method arcs

    my $req = $factory->arcs(includeLoot => 'true');

Returns L<HTTP::Request> for C</arcs> endpoint.

=cut

sub quests {
  my ($self, %params) = @_;
  return $self->_build_request($self->base_url . '/quests', %params);
}

=method quests

    my $req = $factory->quests(type => 'StoryQuest');

Returns L<HTTP::Request> for C</quests> endpoint.

=cut

sub traders {
  my ($self, %params) = @_;
  return $self->_build_request($self->base_url . '/traders', %params);
}

=method traders

    my $req = $factory->traders;

Returns L<HTTP::Request> for C</traders> endpoint.

=cut

sub event_timers {
  my ($self, %params) = @_;
  return $self->_build_request($self->base_url . '/events-schedule', %params);
}

=method event_timers

    my $req = $factory->event_timers(map => 'Dam');

Returns L<HTTP::Request> for C</events-schedule> endpoint.

=cut

sub map_data {
  my ($self, %params) = @_;
  return $self->_build_request($self->map_data_url, %params);
}

=method map_data

    my $req = $factory->map_data(map => 'Spaceport');

Returns L<HTTP::Request> for C</game-map-data> endpoint.

=cut

1;
