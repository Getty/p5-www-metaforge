package WWW::MetaForge::ArcRaiders::Result::EventTimer::TimeSlot;
# ABSTRACT: A time slot with start and end DateTime objects
our $VERSION = '0.003';

use Moo;
use Types::Standard qw(InstanceOf);
use DateTime;
use namespace::clean;

=head1 SYNOPSIS

    my $slot = WWW::MetaForge::ArcRaiders::Result::EventTimer::TimeSlot->from_hashref({
      start => '14:00',
      end   => '15:00',
    });

    say $slot->start;  # DateTime object
    say $slot->end;    # DateTime object

    if ($slot->contains) {
      say "Event is active now!";
    }

=head1 DESCRIPTION

Represents a scheduled time slot with DateTime objects for start and end times.
All times are in UTC.

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

  # New API format: startTime/endTime as millisecond timestamps
  if (exists $data->{startTime}) {
    return $class->from_epoch_ms($data->{startTime}, $data->{endTime});
  }

  # Legacy format: start/end as HH:MM strings
  my $now = DateTime->now(time_zone => 'UTC');
  my $today = $now->clone->truncate(to => 'day');

  my ($start_h, $start_m) = split /:/, $data->{start};
  my ($end_h, $end_m) = split /:/, $data->{end};

  my $start = $today->clone->set(hour => $start_h, minute => $start_m);
  my $end = $today->clone->set(hour => $end_h, minute => $end_m);

  # Handle overnight slots (e.g., 23:00 - 01:00)
  if ($end <= $start) {
    # Slot crosses midnight - determine which day based on current time
    if ($now < $end) {
      # Early morning (after midnight, before slot end) - start was yesterday
      $start->subtract(days => 1);
    } else {
      # Before midnight or after slot end - end is tomorrow
      $end->add(days => 1);
    }
  }

  return $class->new(
    start => $start,
    end   => $end,
  );
}

=method from_hashref

    my $slot = TimeSlot->from_hashref({ start => "HH:MM", end => "HH:MM" });

Construct from API response hash with HH:MM strings or millisecond timestamps.

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
