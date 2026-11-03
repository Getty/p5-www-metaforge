package WWW::MetaForge::ArcRaiders::Result::WeeklyTrial;
# ABSTRACT: Weekly trial result object
our $VERSION = '0.003';
use Moo;
use Types::Standard qw(Str Int Num Bool ArrayRef HashRef Maybe);
use namespace::clean;

has id => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has trial_id => (
  is  => 'ro',
  isa => Str,
);

has name => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has content_name => (
  is  => 'ro',
  isa => Str,
);

has type => (
  is  => 'ro',
  isa => Maybe[Str],
);

has is_active => (
  is      => 'ro',
  isa     => Bool,
  coerce  => sub { $_[0] ? 1 : 0 },
  default => 0,
);

has upcoming => (
  is      => 'ro',
  isa     => Bool,
  coerce  => sub { $_[0] ? 1 : 0 },
  default => 0,
);

has has_event_header => (
  is      => 'ro',
  isa     => Bool,
  coerce  => sub { $_[0] ? 1 : 0 },
  default => 0,
);

has window_id => (
  is  => 'ro',
  isa => Maybe[Int],
);

has window_start => (
  is  => 'ro',
  isa => Maybe[Int],
);

has window_end => (
  is  => 'ro',
  isa => Maybe[Int],
);

has objective_id => (
  is  => 'ro',
  isa => Maybe[Int],
);

has multiplier => (
  is  => 'ro',
  isa => Maybe[Num],
);

has parameters => (
  is      => 'ro',
  isa     => ArrayRef[HashRef],
  default => sub { [] },
);

has map_ids => (
  is      => 'ro',
  isa     => ArrayRef[Int],
  default => sub { [] },
);

has map_names => (
  is      => 'ro',
  isa     => ArrayRef[Str],
  default => sub { [] },
);

has sort_order => (
  is  => 'ro',
  isa => Int,
);

has image_url => (
  is  => 'ro',
  isa => Str,
);

has image_id => (
  is  => 'ro',
  isa => Maybe[Int],
);

has guide_link => (
  is  => 'ro',
  isa => Maybe[Str],
);

has video_link => (
  is  => 'ro',
  isa => Maybe[Str],
);

has database_links => (
  is      => 'ro',
  isa     => ArrayRef[HashRef],
  default => sub { [] },
);

has description_key => (
  is  => 'ro',
  isa => Maybe[Str],
);

has _raw => (
  is       => 'ro',
  isa      => HashRef,
  required => 1,
);

sub from_hashref {
  my ($class, $data) = @_;
  return $class->new(
    id               => $data->{id},
    trial_id         => $data->{trial_id},
    name             => $data->{name},
    content_name     => $data->{content_name},
    type             => $data->{type},
    is_active        => $data->{is_active},
    upcoming         => $data->{upcoming},
    has_event_header => $data->{has_event_header},
    window_id        => $data->{window_id},
    window_start     => $data->{window_start},
    window_end       => $data->{window_end},
    objective_id     => $data->{objective_id},
    multiplier       => $data->{multiplier},
    parameters       => $data->{parameters} // [],
    map_ids          => $data->{map_ids} // [],
    map_names        => $data->{map_names} // [],
    sort_order       => $data->{sort_order},
    image_url        => $data->{image_url},
    image_id         => $data->{image_id},
    guide_link       => $data->{guide_link},
    video_link       => $data->{video_link},
    database_links   => $data->{database_links} // [],
    description_key  => $data->{description_key},
    _raw             => $data,
  );
}

1;

=head1 SYNOPSIS

  my $trials = $api->weekly_trials;
  for my $trial (grep { $_->is_active } @$trials) {
      say $trial->name;
      say '  on ', join(', ', $trial->map_names->@*) if $trial->map_names->@*;
  }

=head1 DESCRIPTION

Represents one entry of the ARC Raiders C</weekly-trials> response. The
response mixes two kinds of entries:

=over 4

=item * Scheduled trials: the trials of the running window
(L</is_active>) and of the next one (L</upcoming>). They carry the window
(L</window_id>, L</window_start>, L</window_end>) and the objective
(L</objective_id>, L</type>, L</multiplier>, L</parameters>); their C<id> is
C<weekly-trial:{trial_id}:{objective_id}:{window_id}>.

=item * Catalog entries: every other trial the site knows, with
L</is_active> and L</upcoming> false and all window and objective fields
C<undef> or empty; their C<id> is C<weekly-trial:{trial_id}>.

=back

Windows that are over are not in the response. L</is_active> and
L</upcoming> describe the moment the API answered.

=attr id

Entry identifier (see L</DESCRIPTION> for its two forms).

=attr trial_id

Trial identifier (e.g. C<0pZHkXCl>).

=attr name

Trial name (e.g. "Damage ARC Turbines").

=attr content_name

The trial's content name. On 2026-11-03 it was the same as L</name> for
every entry.

=attr type

Objective type, C<Damage> or C<Interact>; C<undef> for catalog entries.

=attr is_active

True for the trials of the running window.

=attr upcoming

True for the trials of the next window.

=attr has_event_header

Boolean flag from the API; the API is undocumented and does not say what it
marks. On 2026-11-03 it was true for 31 of 136 entries.

=attr window_id

Integer id of the trial's window; C<undef> for catalog entries.

=attr window_start

Start of the trial's window in epoch B<seconds> (UTC); C<undef> for catalog
entries.

=attr window_end

End of the trial's window in epoch B<seconds> (UTC); C<undef> for catalog
entries.

=attr objective_id

Integer id of the trial's objective; C<undef> for catalog entries.

=attr multiplier

Score multiplier of the objective (e.g. C<1.5>, C<400>); C<undef> for
catalog entries.

=attr parameters

ArrayRef of the objective's parameters, C<< [{ name, value }] >> with both as
strings (e.g. C<< { name => 'Target', value => '414712737' } >>). Empty for
catalog entries, for which the API sends C<null>.

=attr map_ids

ArrayRef of integer map ids the trial is bound to. Empty when the API sends
C<null>, which it does for every trial not bound to a map.

=attr map_names

ArrayRef of map names the trial is bound to (e.g. C<Pendola Pass>).

=attr sort_order

Integer sort position.

=attr image_url

URL of the trial image; an empty string for some entries.

=attr image_id

Integer image id; C<undef> for catalog entries.

=attr guide_link

URL of the trial's guide page on metaforge.app, or C<undef>.

=attr video_link

URL of a guide video, or C<undef>.

=attr database_links

ArrayRef of links into the metaforge.app database (e.g. the ARC the trial
targets): C<< [{ url, label, icon_url }] >>.

=attr description_key

The game's localization key of the trial description (e.g.
C<l0c4l1z3d_164398978>); C<undef> for catalog entries.

=attr _raw

Raw HashRef of the original API data for this entry.

=method from_hashref

  my $trial = WWW::MetaForge::ArcRaiders::Result::WeeklyTrial->from_hashref(\%data);

Construct from API response.

=cut
