package WWW::MetaForge::ArcRaiders::CLI::Cmd::Items;
# ABSTRACT: List items from the ARC Raiders API

use Moo;
use JSON::MaybeXS;
use Getopt::Long qw(:config pass_through);
use namespace::clean;
use MooX::Cmd;

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];

  # Parse options from remaining args
  local @ARGV = @$args;
  my ($search, $limit, $category, $rarity, $page, $all);
  GetOptions(
    'search|s=s'   => \$search,
    'limit|l=i'    => \$limit,
    'category|c=s' => \$category,
    'rarity|r=s'   => \$rarity,
    'page|p=i'     => \$page,
    'all|a'        => \$all,
  );

  my %params;
  $params{search} = $search if $search;
  $params{page} = $page if $page;
  $params{limit} = $limit if $limit;

  my ($items, $pagination);

  if ($all) {
    $items = $app->api->items_all(%params);
  } else {
    my $result = $app->api->items_paginated(%params);
    $items = $result->{data};
    $pagination = $result->{pagination};
  }

  # Apply local filters
  if ($category) {
    my $cat = lc($category);
    $items = [ grep { $_->category && lc($_->category) =~ /\Q$cat\E/ } @$items ];
  }
  if ($rarity) {
    my $rar = lc($rarity);
    $items = [ grep { $_->rarity && lc($_->rarity) eq $rar } @$items ];
  }

  if ($app->json) {
    print JSON::MaybeXS->new(utf8 => 1, pretty => 1)->encode(
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
    my $cat  = $item->category // '-';
    my $rar  = $item->rarity // '-';
    my $id   = $item->slug // $item->id // '-';
    printf "%-40s  %-18s  %-10s  [%s]\n", $name, $cat, $rar, $id;
  }

  my $shown = scalar(@$items);
  if ($pagination && !$all) {
    my $total = $pagination->{total} // '?';
    my $page_num = $pagination->{page} // 1;
    my $total_pages = $pagination->{totalPages} // '?';
    printf "\n%d item(s) shown (page %d/%d, %d total). Use --all to fetch all pages.\n",
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

=head1 DESCRIPTION

Lists items from the ARC Raiders game database.

=head1 OPTIONS

=over 4

=item --search, -s

Search term to filter items by name.

=item --limit, -l

Maximum number of results to display.

=item --category, -c

Filter by item category.

=item --rarity, -r

Filter by item rarity.

=item --page, -p

Page number for pagination.

=item --all, -a

Fetch all pages.

=back

=cut
