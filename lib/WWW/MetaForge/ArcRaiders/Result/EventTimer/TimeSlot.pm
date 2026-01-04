package WWW::MetaForge::ArcRaiders::Result::EventTimer::TimeSlot;
# ABSTRACT: A time slot with start and end DateTime objects

use Moo;
use Types::Standard qw(InstanceOf);
use DateTime;
use namespace::clean;

has start => (
  is       => 'ro',
  isa      => InstanceOf['DateTime'],
  required => 1,
);

has end => (
  is       => 'ro',
  isa      => InstanceOf['DateTime'],
  required => 1,
);

sub from_hashref {
  my ($class, $data) = @_;

  my $today = DateTime->now(time_zone => 'UTC')->truncate(to => 'day');

  my ($start_h, $start_m) = split /:/, $data->{start};
  my ($end_h, $end_m) = split /:/, $data->{end};

  my $start = $today->clone->set(hour => $start_h, minute => $start_m);
  my $end = $today->clone->set(hour => $end_h, minute => $end_m);

  # Handle overnight slots (e.g., 23:00 - 01:00)
  $end->add(days => 1) if $end <= $start;

  return $class->new(
    start => $start,
    end   => $end,
  );
}

sub contains {
  my ($self, $dt) = @_;
  $dt //= DateTime->now(time_zone => 'UTC');
  return $dt >= $self->start && $dt < $self->end;
}

sub minutes_until_start {
  my ($self, $dt) = @_;
  $dt //= DateTime->now(time_zone => 'UTC');
  my $delta = $self->start->epoch - $dt->epoch;
  return int($delta / 60);
}

sub minutes_until_end {
  my ($self, $dt) = @_;
  $dt //= DateTime->now(time_zone => 'UTC');
  my $delta = $self->end->epoch - $dt->epoch;
  return int($delta / 60);
}

1;

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

=attr start

DateTime object for slot start time.

=attr end

DateTime object for slot end time.

=method from_hashref

  my $slot = TimeSlot->from_hashref({ start => "HH:MM", end => "HH:MM" });

Construct from API response hash with HH:MM strings.

=method contains

  if ($slot->contains) { ... }
  if ($slot->contains($datetime)) { ... }

Returns true if the given DateTime (or now) is within this slot.

=method minutes_until_start

  my $mins = $slot->minutes_until_start;

Returns minutes until this slot starts.

=method minutes_until_end

  my $mins = $slot->minutes_until_end;

Returns minutes until this slot ends.

=cut
