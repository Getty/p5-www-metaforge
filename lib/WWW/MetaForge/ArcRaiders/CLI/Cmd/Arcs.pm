package WWW::MetaForge::ArcRaiders::CLI::Cmd::Arcs;
# ABSTRACT: List ARCs from the ARC Raiders API
our $VERSION = '0.003';
use Moo;
use MooX::Cmd;
use MooX::Options;
use JSON::MaybeXS;

option loot => (
  is    => 'ro',
  short => 'l',
  doc   => 'Include loot drop information',
);

option page => (
  is     => 'ro',
  format => 'i',
  short  => 'p',
  doc    => 'Page number for pagination',
);

option all => (
  is    => 'ro',
  short => 'a',
  doc   => 'Fetch all pages',
);

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];
  $app->prepare_output;

  my %params;
  $params{includeLoot} = 'true' if $self->loot;
  $params{page} = $self->page if $self->page;

  my ($arcs, $pagination);

  if ($self->all) {
    $arcs = $app->api->arcs_all(%params);
  } else {
    my $result = $app->api->arcs_paginated(%params);
    $arcs = $result->{data};
    $pagination = $result->{pagination};
  }

  if ($app->json) {
    print JSON::MaybeXS->new(pretty => 1, canonical => 1)->encode(
      [ map { $_->_raw } @$arcs ]
    );
    return;
  }

  if (!@$arcs) {
    print "No ARCs found.\n";
    return;
  }

  for my $arc (@$arcs) {
    my $name = $arc->name // 'Unknown';
    my $id   = $arc->id // '-';
    printf "%-40s  [%s]\n", $name, $id;
    next unless $self->loot;
    print "  (no loot drops)\n" unless @{$arc->loot};
    printf "  %-38s  %s\n", $_->{item}{name}, $_->{item}{rarity} // '-' for @{$arc->loot};
  }

  my $shown = scalar(@$arcs);
  if ($pagination && $pagination->{totalPages} > 1 && !$self->all) {
    my $total = $pagination->{total} // '?';
    my $page_num = $pagination->{page} // 1;
    my $total_pages = $pagination->{totalPages} // '?';
    printf "\n%d ARC(s) shown (page %d/%s, %s total). Use --all to fetch all pages.\n",
      $shown, $page_num, $total_pages, $total;
  } else {
    printf "\n%d ARC(s) found.\n", $shown;
  }
}

1;

=head1 SYNOPSIS

  # List ARCs (first page)
  metaforge-arcraiders arcs

  # List the loot drops under each ARC
  metaforge-arcraiders arcs --loot
  metaforge-arcraiders arcs -l

  # Navigate to specific page
  metaforge-arcraiders arcs --page 2
  metaforge-arcraiders arcs -p 3

  # Fetch all pages
  metaforge-arcraiders arcs --all
  metaforge-arcraiders arcs -a

  # Combine options
  metaforge-arcraiders arcs --loot --all

  # JSON output
  metaforge-arcraiders --json arcs

=head1 DESCRIPTION

This command retrieves and displays a list of ARCs (enemies) from the ARC Raiders
game API. By default, it shows the first page of results with basic information
about each ARC including name and ID.

Results are paginated by the API. Use C<--page> to navigate pages or C<--all> to
fetch all available ARCs across all pages.

=head1 OPTIONS

=head2 --loot, -l

Include loot drop information for each ARC. The API is asked for the loot
(C<includeLoot=true>), and every ARC is followed by the items it drops, indented,
each with its rarity. An ARC without drops gets the line C<(no loot drops)>.
With C<--json> the loot is part of the raw API data.

=head2 --page PAGE, -p PAGE

Retrieve a specific page number. Pages are 1-indexed. Without this option, the first
page is returned.

Cannot be combined with C<--all>.

=head2 --all, -a

Fetch all pages automatically. When enabled, the command retrieves every page of
results and displays all ARCs in a single list.

This may take longer depending on the total number of ARCs.

=head1 OUTPUT

In normal mode, outputs a formatted list with each ARC on its own line:

  ARC Name                                  [ID]
  Another ARC                               [42]

With C<--loot>, the drops follow each ARC:

  ARC Name                                  [ID]
    Item Name                               Rare
    Another Item                            Common
  Another ARC                               [42]
    (no loot drops)

At the end, displays a summary:

  2 ARC(s) found.

For paginated results (without C<--all>), the summary includes pagination details:

  10 ARC(s) shown (page 1/5, 50 total). Use --all to fetch all pages.

With C<--json> global option, outputs raw API response as JSON array.

=cut
