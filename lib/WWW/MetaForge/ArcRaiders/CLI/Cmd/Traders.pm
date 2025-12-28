package WWW::MetaForge::ArcRaiders::CLI::Cmd::Traders;
# ABSTRACT: List traders from the ARC Raiders API

use Moo;
use JSON::MaybeXS;
use namespace::clean;
use MooX::Cmd;

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

=head1 DESCRIPTION

Lists traders from the ARC Raiders game database.

=cut
