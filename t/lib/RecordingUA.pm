package RecordingUA;
use strict;
use warnings;
use JSON::MaybeXS;
use MockUA;
use URI;

# Decorator around MockUA: serves what MockUA serves and remembers every
# request, so a test can count requests and inspect the query. Options:
#   filter_by_id  - honour the `id` query parameter like the live API does:
#                   keep only the records of `data` whose id matches. The
#                   records themselves stay untouched.
#   drop_sections - top-level keys of the response to remove (e.g. 'ermal'),
#                   to serve a response that lacks a section.
# Everything else goes to MockUA unchanged.

sub new {
  my ($class, %args) = @_;
  my $filter = delete $args{filter_by_id};
  my $drop   = delete $args{drop_sections};
  return bless {
    inner         => MockUA->new(%args),
    seen          => [],
    filter_by_id  => $filter,
    drop_sections => $drop || [],
  }, $class;
}

# HTTP::Request objects, in the order they were made
sub seen { @{ $_[0]{seen} } }

# their URIs as strings
sub seen_uris { map { $_->uri . '' } $_[0]->seen }

sub request {
  my ($self, $http_request, @rest) = @_;
  push @{ $self->{seen} }, $http_request;
  my $response = $self->{inner}->request($http_request, @rest);
  return $response unless $response->is_success;

  my %query  = URI->new($http_request->uri)->query_form;
  my $filter = $self->{filter_by_id} && defined $query{id};
  return $response unless $filter || @{ $self->{drop_sections} };

  my $json = JSON::MaybeXS->new(utf8 => 1);
  my $body = $json->decode($response->content);
  delete $body->{$_} for @{ $self->{drop_sections} };
  if ($filter && ref $body->{data} eq 'ARRAY') {
    $body->{data} = [ grep { ($_->{id} // '') eq $query{id} } @{ $body->{data} } ];
  }
  $response->content($json->encode($body));
  return $response;
}

1;
