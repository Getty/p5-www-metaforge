package WWW::MetaForge::Cache;
# ABSTRACT: File-based caching for MetaForge APIs
our $VERSION = '0.003';

use Moo;
use Path::Tiny;
use JSON::MaybeXS;
use Digest::MD5 qw(md5_hex);
use namespace::clean;

=head1 SYNOPSIS

    use WWW::MetaForge::Cache;

    my $cache = WWW::MetaForge::Cache->new;

    my $data = $cache->get('items', { search => 'Ferro' });
    $cache->set('items', { search => 'Ferro' }, $response_data);
    $cache->clear('items');

=head1 DESCRIPTION

File-based caching for MetaForge API responses. Cache files are stored following
XDG Base Directory Specification on Unix (C<~/.cache/metaforge/>) and
LOCALAPPDATA on Windows.

=cut

# Default: 0 = never expire (cache forever until manually cleared)
our %DEFAULT_TTL = ();

has namespace => (
  is      => 'ro',
  default => 'metaforge',
);

=attr namespace

Directory name for cache. Defaults to C<metaforge>.

=cut

has cache_dir => (
  is      => 'ro',
  lazy    => 1,
  builder => '_build_cache_dir',
  coerce  => sub { ref $_[0] ? $_[0] : path($_[0]) },
);

=attr cache_dir

L<Path::Tiny> object for cache directory. Auto-detected based on OS.
Accepts string (coerced to Path::Tiny).

=cut

has ttl => (
  is      => 'ro',
  default => sub { +{ %DEFAULT_TTL } },
);

=attr ttl

HashRef of TTL values per endpoint in seconds.
Default is empty (cache never expires). Use 0 or undef for infinite TTL.

Example with expiration:

    my $cache = WWW::MetaForge::Cache->new(
      ttl => { event_timers => 300 }  # 5 minutes for events only
    );

=cut

has json => (
  is      => 'ro',
  lazy    => 1,
  default => sub { JSON::MaybeXS->new(utf8 => 1, canonical => 1) },
);

=attr json

L<JSON::MaybeXS> instance for serialization.

=cut

sub _build_cache_dir {
  my ($self) = @_;
  my $dir;

  if ($^O eq 'MSWin32') {
    $dir = path($ENV{LOCALAPPDATA} // $ENV{TEMP} // 'C:/Temp', $self->namespace);
  } else {
    my $base = $ENV{XDG_CACHE_HOME} // path($ENV{HOME}, '.cache');
    $dir = path($base, $self->namespace);
  }

  $dir->mkpath unless $dir->is_dir;
  return $dir;
}

sub _cache_key {
  my ($self, $endpoint, $params) = @_;
  my $param_str = $self->json->encode($params // {});
  return $endpoint . '_' . md5_hex($param_str) . '.json';
}

sub _cache_file {
  my ($self, $endpoint, $params) = @_;
  return path($self->cache_dir, $self->_cache_key($endpoint, $params));
}

sub get {
  my ($self, $endpoint, $params) = @_;

  my $file = $self->_cache_file($endpoint, $params);
  return undef unless $file->is_file;

  my $cached = eval { $self->json->decode($file->slurp_utf8) };
  return undef unless $cached && ref $cached eq 'HASH';

  # TTL 0 or undef = never expire
  my $ttl = $self->ttl->{$endpoint};
  if ($ttl) {
    my $age = time() - ($cached->{timestamp} // 0);
    return undef if $age > $ttl;
  }

  return $cached->{data};
}

=method get

    my $data = $cache->get($endpoint, \%params);

Returns cached data or undef if missing/expired.

=cut

sub set {
  my ($self, $endpoint, $params, $data) = @_;

  my $file = $self->_cache_file($endpoint, $params);
  my $cached = {
    timestamp => time(),
    endpoint  => $endpoint,
    params    => $params,
    data      => $data,
  };

  $file->spew_utf8($self->json->encode($cached));
  return $data;
}

=method set

    $cache->set($endpoint, \%params, $data);

Store data in cache with timestamp.

=cut

sub clear {
  my ($self, $endpoint) = @_;

  if (defined $endpoint) {
    for my $file ($self->cache_dir->children(qr/^\Q$endpoint\E_/)) {
      $file->remove;
    }
  } else {
    $_->remove for $self->cache_dir->children(qr/\.json$/);
  }
}

=method clear

    $cache->clear('items');  # Clear specific endpoint
    $cache->clear;           # Clear all

Remove cached files.

=cut

sub clear_all {
  my ($self) = @_;
  $self->clear();
}

=method clear_all

Alias for C<< $cache->clear >>.

=cut

1;
