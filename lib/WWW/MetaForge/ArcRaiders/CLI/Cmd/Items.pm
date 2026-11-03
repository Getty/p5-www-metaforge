package WWW::MetaForge::ArcRaiders::CLI::Cmd::Items;
# ABSTRACT: List items from the ARC Raiders API
our $VERSION = '0.003';
use Moo;
use MooX::Cmd;
use MooX::Options;
use JSON::MaybeXS;

option search => (
  is      => 'ro',
  format  => 's',
  short   => 's',
  doc     => 'Search term to filter items by name',
);

option limit => (
  is      => 'ro',
  format  => 'i',
  short   => 'l',
  doc     => 'Maximum number of results to display',
);

option category => (
  is      => 'ro',
  format  => 's',
  short   => 'c',
  doc     => 'Filter by item category (exact API item_type, e.g. "Quick Use")',
);

option rarity => (
  is      => 'ro',
  format  => 's',
  short   => 'r',
  doc     => 'Filter by item rarity (exact API value, e.g. "Legendary")',
);

option page => (
  is      => 'ro',
  format  => 'i',
  short   => 'p',
  doc     => 'Page number for pagination',
);

option all => (
  is      => 'ro',
  short   => 'a',
  doc     => 'Fetch all pages',
);

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];
  $app->prepare_output;

  my %params;
  $params{search} = $self->search if $self->search;
  $params{item_type} = $self->category if $self->category;
  $params{rarity} = $self->rarity if $self->rarity;
  $params{page} = $self->page if $self->page;
  $params{limit} = $self->limit if $self->limit;

  my ($items, $pagination);

  if ($self->all) {
    $items = $app->api->items_all(%params);
  } else {
    my $result = $app->api->items_paginated(%params);
    $items = $result->{data};
    $pagination = $result->{pagination};
  }

  if ($app->json) {
    print JSON::MaybeXS->new(pretty => 1)->encode(
      [ map { $_->_raw } @$items ]
    );
    return;
  }

  if (!@$items) {
    print "No items found.\n";
    return;
  }

  for my $item (@$items) {
    my $name = $item->name // $item->id // 'Unknown';
    my $cat  = $item->item_type // '-';
    my $rar  = $item->rarity // '-';
    my $id   = $item->id // '-';
    printf "%-40s  %-18s  %-10s  [%s]\n", $name, $cat, $rar, $id;
  }

  my $shown = scalar(@$items);
  if ($pagination && !$self->all) {
    my $total = $pagination->{total} // '?';
    my $page_num = $pagination->{page} // 1;
    my $total_pages = $pagination->{totalPages} // '?';
    printf "\n%d item(s) shown (page %d/%s, %s total). Use --all to fetch all pages.\n",
      $shown, $page_num, $total_pages, $total;
  } else {
    printf "\n%d item(s) found.\n", $shown;
  }
}

1;

=head1 SYNOPSIS

  arcraiders items
  arcraiders items --search Ferro
  arcraiders items --category Weapon --rarity Rare
  arcraiders items --category 'Quick Use' --all

=head1 DESCRIPTION

Lists items from the ARC Raiders game database.

=head1 OPTIONS

=over 4

=item --search, -s

Search term to filter items by name.

=item --limit, -l

Maximum number of results to display.

=item --category, -c

Filter by item category. The API filters on C<item_type> and matches the
exact, case-sensitive value (C<Weapon>, C<Quick Use>, C<Topside Material>).

=item --rarity, -r

Filter by item rarity. The API matches the exact, case-sensitive value
(C<Common>, C<Uncommon>, C<Rare>, C<Epic>, C<Legendary>, C<Amplified>).

=item --page, -p

Page number for pagination.

=item --all, -a

Fetch all pages.

=back

=cut
