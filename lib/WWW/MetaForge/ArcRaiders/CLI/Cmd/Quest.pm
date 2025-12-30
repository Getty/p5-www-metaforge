package WWW::MetaForge::ArcRaiders::CLI::Cmd::Quest;
# ABSTRACT: Show details for a single quest

use Moo;
use MooX::Cmd;
use MooX::Options;
use JSON::MaybeXS;

sub execute {
  my ($self, $args, $chain) = @_;
  my $app = $chain->[0];

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
    print JSON::MaybeXS->new(utf8 => 1, pretty => 1)->encode($quest->_raw);
    return;
  }

  _print_quest_details($quest);
}

sub _print_quest_details {
  my ($quest) = @_;

  print "=" x 60, "\n";
  printf "%s\n", $quest->name // 'Unknown';
  print "=" x 60, "\n";

  _print_field("ID",   $quest->id);
  _print_field("Type", $quest->type);

  if ($quest->description) {
    print "\nDescription:\n";
    my $desc = $quest->description;
    $desc =~ s/(.{1,58})\s/$1\n  /g;  # Word wrap
    print "  $desc\n";
  }

  if ($quest->objectives && @{$quest->objectives}) {
    print "\nObjectives:\n";
    my $i = 1;
    for my $obj (@{$quest->objectives}) {
      printf "  %d. %s\n", $i++, $obj;
    }
  }

  if ($quest->required_items && @{$quest->required_items}) {
    print "\nRequired Items:\n";
    for my $req (@{$quest->required_items}) {
      my $name = $req->{item} // $req->{name} // 'Unknown';
      my $qty  = $req->{quantity} // $req->{amount} // 1;
      printf "  %dx %s\n", $qty, $name;
    }
  }

  my @reward_parts;
  push @reward_parts, $quest->xp_reward . " XP" if $quest->xp_reward;
  push @reward_parts, $quest->reputation_reward . " Rep" if $quest->reputation_reward;

  if (@reward_parts) {
    print "\nRewards:\n";
    print "  ", join(", ", @reward_parts), "\n";
  }

  if ($quest->rewards && @{$quest->rewards}) {
    print "  Item Rewards:\n" unless @reward_parts;
    for my $reward (@{$quest->rewards}) {
      if (ref $reward eq 'HASH') {
        my $name = $reward->{item} // $reward->{name} // next;
        my $qty  = $reward->{quantity} // $reward->{amount} // 1;
        printf "    %dx %s\n", $qty, $name;
      }
    }
  }

  if ($quest->prev_quest || $quest->next_quest) {
    print "\nQuest Chain:\n";
    printf "  Previous: %s\n", $quest->prev_quest // '-';
    printf "  Next:     %s\n", $quest->next_quest // '-';
  }

  if ($quest->last_updated) {
    print "\nLast Updated: ", $quest->last_updated, "\n";
  }
}

sub _print_field {
  my ($label, $value) = @_;
  return unless defined $value;
  printf "%-15s %s\n", "$label:", $value;
}

1;
