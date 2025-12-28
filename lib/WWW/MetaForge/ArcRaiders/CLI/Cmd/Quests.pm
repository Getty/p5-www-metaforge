package WWW::MetaForge::ArcRaiders::CLI::Cmd::Quests;
# ABSTRACT: List quests from the ARC Raiders API

use Moo;
use JSON::MaybeXS;
use Getopt::Long qw(:config pass_through);
use namespace::clean;
use MooX::Cmd;

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];

  local @ARGV = @$args;
  my ($type, $page, $all);
  GetOptions(
    'type|t=s' => \$type,
    'page|p=i' => \$page,
    'all|a'    => \$all,
  );

  my %params;
  $params{type} = $type if $type;
  $params{page} = $page if $page;

  my ($quests, $pagination);

  if ($all) {
    $quests = $app->api->quests_all(%params);
  } else {
    my $result = $app->api->quests_paginated(%params);
    $quests = $result->{data};
    $pagination = $result->{pagination};
  }

  if ($app->json) {
    print JSON::MaybeXS->new(utf8 => 1, pretty => 1)->encode(
      [ map { $_->_raw } @$quests ]
    );
    return;
  }

  if (!@$quests) {
    print "No quests found.\n";
    return;
  }

  for my $quest (@$quests) {
    my $name = $quest->name // 'Unknown';
    my $id   = $quest->id // '-';
    printf "%-50s  [%s]\n", $name, $id;
  }

  my $shown = scalar(@$quests);
  if ($pagination && !$all) {
    my $total = $pagination->{total} // '?';
    my $page_num = $pagination->{page} // 1;
    my $total_pages = $pagination->{totalPages} // '?';
    printf "\n%d quest(s) shown (page %d/%d, %d total). Use --all to fetch all pages.\n",
      $shown, $page_num, $total_pages, $total;
  } else {
    printf "\n%d quest(s) found.\n", $shown;
  }
}

1;

=head1 SYNOPSIS

  arcraiders quests
  arcraiders quests --type daily

=head1 DESCRIPTION

Lists quests from the ARC Raiders game database.

=head1 OPTIONS

=over 4

=item --type, -t

Filter by quest type.

=item --page, -p

Page number for pagination.

=item --all, -a

Fetch all pages.

=back

=cut
