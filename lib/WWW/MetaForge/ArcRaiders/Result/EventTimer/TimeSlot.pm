package WWW::MetaForge::ArcRaiders::Result::EventTimer::TimeSlot;
# ABSTRACT: A time slot with start and end DateTime objects
our $VERSION = '0.003';

use Moo;
use Types::Standard qw(InstanceOf);
use DateTime;
use namespace::clean;

=head1 SYNOPSIS

    # one record of the events-schedule response
    my $slot = WWW::MetaForge::ArcRaiders::Result::EventTimer::TimeSlot->from_hashref({
      name      => 'Night Raid',
      map       => 'Spaceport',
      icon      => 'https://static.metaforge.app/arc-raiders/custom/night.webp',
      startTime => 1793653200000,
      endTime   => 1793656800000,
    });

    say $slot->start;  # DateTime object, 2026-11-02T21:00:00
    say $slot->end;    # DateTime object, 2026-11-02T22:00:00

    if ($slot->contains) {
      say "Event is active now!";
    }

=head1 DESCRIPTION

Represents one scheduled run of an event with DateTime objects for start and
end times. The C</events-schedule> endpoint sends one record per run, with
C<startTime> and C<endTime> in epoch milliseconds. All times are in UTC.

=cut

has start => (
  is       => 'ro',
  isa      => InstanceOf['DateTime'],
  required => 1,
);

=attr start

DateTime object for slot start time.

=cut

has end => (
  is       => 'ro',
  isa      => InstanceOf['DateTime'],
  required => 1,
);

=attr end

DateTime object for slot end time.

=cut

sub from_hashref {
  my ($class, $data) = @_;
  return $class->from_epoch_ms($data->{startTime}, $data->{endTime});
}

=method from_hashref

    my $slot = TimeSlot->from_hashref($record);

Construct from one record of the C</events-schedule> response. Reads only
C<startTime> and C<endTime> (epoch milliseconds); name, map and icon belong
to the L<WWW::MetaForge::ArcRaiders::Result::EventTimer> that groups the
records.

=cut

sub from_epoch_ms {
  my ($class, $start_ms, $end_ms) = @_;

  my $start = DateTime->from_epoch(
    epoch     => int($start_ms / 1000),
    time_zone => 'UTC',
  );
  my $end = DateTime->from_epoch(
    epoch     => int($end_ms / 1000),
    time_zone => 'UTC',
  );

  return $class->new(
    start => $start,
    end   => $end,
  );
}

=method from_epoch_ms

    my $slot = TimeSlot->from_epoch_ms($start_ms, $end_ms);

Construct from epoch milliseconds timestamps.

=cut

sub contains {
  my ($self, $dt) = @_;
  $dt //= DateTime->now(time_zone => 'UTC');
  return $dt >= $self->start && $dt < $self->end;
}

=method contains

    if ($slot->contains) { ... }
    if ($slot->contains($datetime)) { ... }

Returns true if the given DateTime (or now) is within this slot.

=cut

sub minutes_until_start {
  my ($self, $dt) = @_;
  $dt //= DateTime->now(time_zone => 'UTC');
  my $delta = $self->start->epoch - $dt->epoch;
  return int($delta / 60);
}

=method minutes_until_start

    my $mins = $slot->minutes_until_start;

Returns minutes until this slot starts.

=cut

sub minutes_until_end {
  my ($self, $dt) = @_;
  $dt //= DateTime->now(time_zone => 'UTC');
  my $delta = $self->end->epoch - $dt->epoch;
  return int($delta / 60);
}

=method minutes_until_end

    my $mins = $slot->minutes_until_end;

Returns minutes until this slot ends.

=cut

1;
