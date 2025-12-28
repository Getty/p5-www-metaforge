package WWW::MetaForge;
# ABSTRACT: Perl client for MetaForge gaming APIs

use strict;
use warnings;

1;

=head1 SYNOPSIS

  # ARC Raiders API
  use WWW::MetaForge::ArcRaiders;

  my $api = WWW::MetaForge::ArcRaiders->new;
  my $items = $api->items(search => 'Ferro');

  # Generic Game Map Data API
  use WWW::MetaForge::GameMapData;

  my $maps = WWW::MetaForge::GameMapData->new;
  my $markers = $maps->map_data(map => 'Dam');

=head1 DESCRIPTION

WWW::MetaForge provides Perl interfaces to the MetaForge gaming APIs.

=head2 Available APIs

=over 4

=item * L<WWW::MetaForge::ArcRaiders> - ARC Raiders game data (items, quests, traders, events, maps)

=item * L<WWW::MetaForge::GameMapData> - Generic game map marker data

=back

=head1 CLI

The distribution includes the C<arcraiders> command-line tool:

  arcraiders items --search Ferro
  arcraiders item ferro-i
  arcraiders events --active
  arcraiders traders

=head1 ATTRIBUTION

This module uses the MetaForge API: L<https://metaforge.app>

Data is community-maintained. Please attribute MetaForge when using
this data in public projects.

=head1 SEE ALSO

L<https://metaforge.app/arc-raiders/api>

=cut
