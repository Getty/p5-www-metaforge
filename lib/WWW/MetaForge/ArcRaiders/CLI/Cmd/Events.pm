package WWW::MetaForge::ArcRaiders::CLI::Cmd::Events;
# ABSTRACT: Show event timers from the ARC Raiders API

use Moo;
use JSON::MaybeXS;
use Getopt::Long qw(:config pass_through);
use namespace::clean;
use MooX::Cmd;

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];

  local @ARGV = @$args;
  my $active;
  GetOptions('active|a' => \$active);

  my $events = $app->api->event_timers;

  if ($active) {
    $events = [ grep { $_->is_active_now } @$events ];
  }

  # Sort chronologically: active events first (by time until end), then upcoming (by time until start)
  $events = [
    sort {
      my $a_active = $a->is_active_now;
      my $b_active = $b->is_active_now;

      # Active events come first
      return -1 if $a_active && !$b_active;
      return 1 if !$a_active && $b_active;

      # Both active: sort by time until end
      if ($a_active) {
        return ($a->minutes_until_end // 9999) <=> ($b->minutes_until_end // 9999);
      }

      # Both inactive: sort by time until start
      return ($a->minutes_until_start // 9999) <=> ($b->minutes_until_start // 9999);
    } @$events
  ];

  if ($app->json) {
    print JSON::MaybeXS->new(utf8 => 1, pretty => 1)->encode(
      [ map { $_->_raw } @$events ]
    );
    return;
  }

  if (!@$events) {
    print "No events found.\n";
    return;
  }

  for my $event (@$events) {
    my $name   = $event->name // 'Unknown';
    my $map    = $event->map // '';
    my $status = $event->is_active_now ? '[ACTIVE]' : '';
    my $time_info = '';

    if ($event->is_active_now) {
      my $remaining = $event->time_until_end;
      $time_info = "ends in $remaining" if $remaining;
    } else {
      my $until = $event->time_until_start;
      $time_info = "in $until" if $until;
    }

    printf "%-30s  %-15s  %-10s  %s\n", $name, $map, $status, $time_info;
  }

  printf "\n%d event(s) found.\n", scalar(@$events);
}

1;

=head1 SYNOPSIS

  arcraiders events
  arcraiders events --active

=head1 DESCRIPTION

Shows event timers from the ARC Raiders game.

=head1 OPTIONS

=over 4

=item --active, -a

Show only currently active events.

=back

=cut
