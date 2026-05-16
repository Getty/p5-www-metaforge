package WWW::MetaForge::ArcRaiders::Result::Arc;
# ABSTRACT: Arc (mission/event) result object
our $VERSION = '0.003';
use Moo;
use Types::Standard qw(Str Maybe HashRef);
use namespace::clean;

has id => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has name => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has description => (
  is  => 'ro',
  isa => Maybe[Str],
);

has icon => (
  is  => 'ro',
  isa => Maybe[Str],
);

has image => (
  is  => 'ro',
  isa => Maybe[Str],
);

has created_at => (
  is  => 'ro',
  isa => Maybe[Str],
);

has updated_at => (
  is  => 'ro',
  isa => Maybe[Str],
);

has _raw => (
  is  => 'ro',
  isa => HashRef,
);

sub from_hashref {
  my ($class, $data) = @_;

  return $class->new(
    id          => $data->{id},
    name        => $data->{name},
    description => $data->{description},
    icon        => $data->{icon},
    image       => $data->{image},
    created_at  => $data->{created_at},
    updated_at  => $data->{updated_at},
    _raw        => $data,
  );
}

1;

=head1 SYNOPSIS

  my $arcs = $api->arcs;
  for my $arc (@$arcs) {
      say $arc->name;
  }

=head1 DESCRIPTION

Represents an ARC (mission/event) from the ARC Raiders game.

=attr id

Arc identifier.

=attr name

Arc name.

=attr description

Arc description text.

=attr icon

Icon URL or identifier.

=attr image

Image URL.

=attr created_at

ISO timestamp of creation.

=attr updated_at

ISO timestamp of last update.

=method from_hashref

  my $arc = WWW::MetaForge::ArcRaiders::Result::Arc->from_hashref(\%data);

Construct from API response.

=cut