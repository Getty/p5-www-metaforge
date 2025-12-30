package WWW::MetaForge::ArcRaiders::CLI::Cmd::Traders;
# ABSTRACT: List traders from the ARC Raiders API

use Moo;
use MooX::Cmd;
use MooX::Options;
use JSON::MaybeXS;

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];

  my $traders = $app->api->traders;

  if ($app->json) {
    print JSON::MaybeXS->new(utf8 => 1, pretty => 1)->encode(
      [ map { $_->_raw } @$traders ]
    );
    return;
  }

  if (!@$traders) {
    print "No traders found.\n";
    return;
  }

  for my $trader (@$traders) {
    my $name = $trader->name // 'Unknown';
    my $inv_count = $trader->inventory ? scalar(@{$trader->inventory}) : 0;
    printf "%-30s  (%d items)\n", $name, $inv_count;
  }

  printf "\n%d trader(s) found.\n", scalar(@$traders);
}

1;

=head1 SYNOPSIS

  arcraiders traders
  arcraiders traders --json

=head1 DESCRIPTION

List all traders from the ARC Raiders API. Displays trader names and their
inventory counts in a simple table format.

Use the C<--json> flag (inherited from parent command) to output raw API data
as JSON instead of formatted text.

=cut
