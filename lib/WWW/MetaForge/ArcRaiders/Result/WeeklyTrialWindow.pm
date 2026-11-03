package WWW::MetaForge::ArcRaiders::Result::WeeklyTrialWindow;
# ABSTRACT: Window times from the weekly trials response
our $VERSION = '0.003';
use Moo;
use Types::Standard qw(Int HashRef);
use namespace::clean;

has active_window_end => (
  is  => 'ro',
  isa => Int,
);

has next_window_start => (
  is  => 'ro',
  isa => Int,
);

has _raw => (
  is       => 'ro',
  isa      => HashRef,
  required => 1,
);

sub from_hashref {
  my ($class, $data) = @_;
  return $class->new(
    active_window_end => $data->{activeWindowEnd},
    next_window_start => $data->{nextWindowStart},
    _raw              => $data,
  );
}

1;

=head1 SYNOPSIS

  my $window = $api->weekly_trials_window;
  printf "Running trials end at %s UTC\n", scalar gmtime $window->active_window_end;
  printf "Next trials start at %s UTC\n",  scalar gmtime $window->next_window_start;

=head1 DESCRIPTION

Represents the window times the ARC Raiders C</weekly-trials> response sends
next to its C<data> list. Get it with
L<WWW::MetaForge::ArcRaiders/weekly_trials_window>. Both times are epoch
B<seconds> (UTC), unlike the milliseconds of C</events-schedule>.

=attr active_window_end

When the running trial window ends, in epoch seconds.

=attr next_window_start

When the next trial window starts, in epoch seconds. On 2026-11-03 the
windows were two hours apart.

=attr _raw

The top-level keys of the response other than C<data>, untouched
(C<< { activeWindowEnd, nextWindowStart } >>).

=method from_hashref

  my $window = WWW::MetaForge::ArcRaiders::Result::WeeklyTrialWindow->from_hashref(\%data);

Construct from the top-level keys of the response other than C<data>.

=cut
