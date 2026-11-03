package WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest;
# ABSTRACT: Show details for a single quest
our $VERSION = '0.003';
use Moo;
use MooX::Cmd;
use MooX::Options;
use JSON::MaybeXS;

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];
  $app->prepare_output;

  my $quest_id = $args->[0];
  unless ($quest_id) {
    print "Usage: arcraiders quest <id>\n";
    print "Example: arcraiders quest a-bad-feeling\n";
    return;
  }

  # Try fetching by ID first (API supports id= query param)
  my $result = $app->api->quests_paginated(id => $quest_id);
  my $quests = $result->{data};

  # If not found by ID, search all quests
  if (!@$quests) {
    $quests = $app->api->quests_all;
    my ($match) = grep {
      ($_->id && lc($_->id) eq lc($quest_id)) ||
      ($_->name && lc($_->name) eq lc($quest_id))
    } @$quests;
    $quests = $match ? [$match] : [];
  }

  unless (@$quests) {
    print "Quest '$quest_id' not found.\n";
    return;
  }

  my $quest = $quests->[0];

  if ($app->json) {
    print JSON::MaybeXS->new(pretty => 1, canonical => 1)->encode($quest->_raw);
    return;
  }

  _print_quest_details($quest);
}

sub _print_quest_details {
  my ($quest) = @_;

  print "=" x 60, "\n";
  printf "%s\n", $quest->name // 'Unknown';
  print "=" x 60, "\n";

  _print_field("ID", $quest->id);
  _print_field("Trader", $quest->trader_name);

  my @prerequisites = @{ $quest->manifest->{prerequisites} // [] };
  _print_field("Requires", join(', ', map { $_->{name} } @prerequisites)) if @prerequisites;

  if (defined $quest->description && length $quest->description) {
    print "\nDescription:\n";
    (my $desc = $quest->description) =~ s/\A\s+|\s+\z//g;
    $desc =~ s/\s+/ /g;
    $desc =~ s/(.{1,58})(?:\s|\z)/  $1\n/g;  # Word wrap
    print $desc;
  }

  if ($quest->objectives && @{$quest->objectives}) {
    print "\nObjectives:\n";
    my $i = 1;
    for my $obj (@{$quest->objectives}) {
      printf "  %d. %s\n", $i++, $obj;
    }
  }

  if (@{$quest->required_items}) {
    print "\nRequired Items:\n";
    printf "  %dx %s\n", $_->{quantity}, $_->{item}{name} for @{$quest->required_items};
  }

  if (@{$quest->granted_items}) {
    print "\nGranted Items:\n";
    printf "  %dx %s\n", $_->{quantity}, $_->{item}{name} for @{$quest->granted_items};
  }

  my @rewards = (
    ( map { _additional_reward($_) } @{$quest->additional_rewards} ),
    ( map { sprintf '%dx %s', $_->{quantity}, $_->{item}{name} } @{$quest->rewards} ),
  );
  if (@rewards) {
    print "\nRewards:\n";
    print "  $_\n" for @rewards;
  }

  if ($quest->updated_at) {
    print "\nLast Updated: ", $quest->updated_at, "\n";
  }
}

# additional_rewards: currency ("5000 XP") or cosmetic-option
# ("Aviator Color: Dusted Cream")
sub _additional_reward {
  my ($reward) = @_;
  return $reward->{kind} eq 'cosmetic-option'
    ? sprintf('%s %s: %s', $reward->{group}, $reward->{setting}, $reward->{name})
    : sprintf('%d %s', $reward->{quantity}, $reward->{name});
}

sub _print_field {
  my ($label, $value) = @_;
  return unless defined $value;
  printf "%-15s %s\n", "$label:", $value;
}

1;

=head1 SYNOPSIS

  # Show quest details by ID
  arcraiders quest a-bad-feeling

  # Show quest details by name
  arcraiders quest "A Bad Feeling"

  # Output as JSON
  arcraiders quest a-bad-feeling --json

=head1 DESCRIPTION

This command displays detailed information for a single quest. It accepts either
a quest ID or quest name as the argument.

The command first attempts to fetch the quest by ID using the API. If not found,
it falls back to searching the complete quest list by matching against both the
ID and name fields (case-insensitive).

Quest details displayed include:

=over 4

=item * Name, ID, the trader who gives the quest and the quests to finish first

=item * Description text

=item * Objectives list

=item * Required and granted items with quantities

=item * Rewards (XP, coins, cosmetics and items)

=item * Last updated timestamp

=back

When the C<--json> flag is used, the raw quest data is output as JSON instead
of the formatted display.

=cut
