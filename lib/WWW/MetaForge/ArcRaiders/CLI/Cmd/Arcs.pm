package WWW::MetaForge::ArcRaiders::CLI::Cmd::Arcs;
# ABSTRACT: List ARCs from the ARC Raiders API

use Moo;
use JSON::MaybeXS;
use Getopt::Long qw(:config pass_through);
use namespace::clean;
use MooX::Cmd;

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];

  local @ARGV = @$args;
  my ($loot, $page, $all);
  GetOptions(
    'loot|l'   => \$loot,
    'page|p=i' => \$page,
    'all|a'    => \$all,
  );

  my %params;
  $params{includeLoot} = 1 if $loot;
  $params{page} = $page if $page;

  my ($arcs, $pagination);

  if ($all) {
    $arcs = $app->api->arcs_all(%params);
  } else {
    my $result = $app->api->arcs_paginated(%params);
    $arcs = $result->{data};
    $pagination = $result->{pagination};
  }

  if ($app->json) {
    print JSON::MaybeXS->new(utf8 => 1, pretty => 1)->encode(
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
  }

  my $shown = scalar(@$arcs);
  if ($pagination && $pagination->{totalPages} > 1 && !$all) {
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

  arcraiders arcs
  arcraiders arcs --loot

=head1 DESCRIPTION

Lists ARCs (enemies/robots) from the ARC Raiders game database.

=head1 OPTIONS

=over 4

=item --loot, -l

Include loot drop information.

=item --page, -p

Page number for pagination.

=item --all, -a

Fetch all pages.

=back

=cut
