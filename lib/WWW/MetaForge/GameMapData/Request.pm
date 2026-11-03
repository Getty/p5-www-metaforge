package WWW::MetaForge::GameMapData::Request;
# ABSTRACT: HTTP request builder for MetaForge Game Map Data API
our $VERSION = '0.003';

use Moo;
use HTTP::Request;
use URI;
use namespace::clean;

=head1 SYNOPSIS

    use WWW::MetaForge::GameMapData::Request;

    my $req = WWW::MetaForge::GameMapData::Request->new;

    # Build request for map data
    my $http_req = $req->map_data(map => 'dam');

=head1 DESCRIPTION

Builds L<HTTP::Request> objects for the MetaForge Game Map Data API.
Useful for integrating with async HTTP frameworks.

=cut

has base_url => (
  is      => 'ro',
  default => 'https://metaforge.app/api/game-map-data',
);

=attr base_url

Base URL for the API. Defaults to C<https://metaforge.app/api/game-map-data>.

=cut

sub _build_request {
  my ($self, %params) = @_;

  my $uri = URI->new($self->base_url);
  $uri->query_form(%params) if %params;

  return HTTP::Request->new(GET => $uri);
}

sub map_data {
  my ($self, %params) = @_;
  # tableID is required for arc-raiders map data
  $params{tableID} //= 'arc_map_data';
  # Accept 'map' as alias for 'mapID'
  $params{mapID} //= delete $params{map} if exists $params{map};
  return $self->_build_request(%params);
}

=method map_data

    my $http_req = $req->map_data(map => 'dam');

Returns L<HTTP::Request> for fetching map marker data. C<map> is sent as
C<mapID>, C<tableID> defaults to C<arc_map_data>.

=cut

1;
