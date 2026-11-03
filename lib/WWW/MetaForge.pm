package WWW::MetaForge;
# ABSTRACT: Perl client for MetaForge gaming APIs
our $VERSION = '0.003';
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

=item * L<WWW::MetaForge::ArcRaiders> - ARC Raiders game data (items, ARCs, quests, traders, Ermal's offers, hideout stations, weekly trials, event timers, map data)

=item * L<WWW::MetaForge::GameMapData> - Generic game map marker data

=back

=head1 CLI

The distribution includes the C<arcraiders> command-line tool:

  arcraiders items --search Ferro
  arcraiders item ferro-i
  arcraiders events --active
  arcraiders traders

=head1 ATTRIBUTION

All game data comes from MetaForge ARC Raiders, maintained by the
MetaForge team and community contributors:
L<https://metaforge.app/arc-raiders>

A public project using this data must attribute MetaForge and link to
that page. The terms of usage are quoted in
L<WWW::MetaForge::ArcRaiders/ATTRIBUTION>.

=head1 SEE ALSO

L<https://metaforge.app/arc-raiders/api>

=cut
