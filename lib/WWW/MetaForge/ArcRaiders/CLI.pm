package WWW::MetaForge::ArcRaiders::CLI;
# ABSTRACT: CLI application for MetaForge ARC Raiders API
our $VERSION = '0.003';

use Moo;
use WWW::MetaForge::ArcRaiders;
use Carp qw(croak);
use Encode qw(decode FB_CROAK LEAVE_SRC);
use Getopt::Long qw(:config pass_through);
use namespace::clean;
use MooX::Cmd;

=head1 SYNOPSIS

    use WWW::MetaForge::ArcRaiders::CLI;
    WWW::MetaForge::ArcRaiders::CLI->new_with_cmd;

=head1 DESCRIPTION

Main CLI class for the ARC Raiders API client. Uses L<MooX::Cmd> for
subcommand handling.

=cut

has debug => (
  is      => 'ro',
  default => sub { $ENV{WWW_METAFORGE_ARCRAIDERS_DEBUG} // 0 },
);

=attr debug

Enable debug output. Use C<--debug> or C<-d> flag, or set via
C<WWW_METAFORGE_ARCRAIDERS_DEBUG> environment variable.

=cut

has no_cache => (
  is      => 'ro',
  default => sub { $ENV{WWW_METAFORGE_ARCRAIDERS_NO_CACHE} // 0 },
);

=attr no_cache

Disable response caching. Use C<--no-cache> flag, or set via
C<WWW_METAFORGE_ARCRAIDERS_NO_CACHE> environment variable.

=cut

has json => (
  is      => 'ro',
  default => sub { $ENV{WWW_METAFORGE_ARCRAIDERS_JSON} // 0 },
);

=attr json

Output results as JSON. Use C<--json> or C<-j> flag, or set via
C<WWW_METAFORGE_ARCRAIDERS_JSON> environment variable.

=cut

before new_with_cmd => sub {
  # perl decoded @ARGV itself under -CA or PERL_UNICODE=A
  return if ${^UNICODE} & 32;
  @ARGV = map {
    my $arg   = $_;
    my $chars = eval { decode('UTF-8', $arg, FB_CROAK | LEAVE_SRC) };
    croak __PACKAGE__.'->new_with_cmd: command line argument is not UTF-8: '.$arg
      unless defined $chars;
    $chars;
  } @ARGV;
};

=method new_with_cmd

    WWW::MetaForge::ArcRaiders::CLI->new_with_cmd;

Decodes C<@ARGV> from UTF-8 before L<MooX::Cmd> and L<MooX::Options> read
it, so command arguments and option values are character strings like the
names in the API data: C<quest "CelesteE<0x2019>s Journals"> finds the quest. An
argument that is not valid UTF-8 croaks. When perl has decoded C<@ARGV>
already (C<-CA>, or C<A> in C<PERL_UNICODE>) it is left as it is.

=cut

around BUILDARGS => sub {
  my ($orig, $class, @args) = @_;

  # Parse global options from @ARGV before MooX::Cmd processes it
  my ($debug, $no_cache, $json);
  GetOptions(
    'debug|d'    => \$debug,
    'no-cache'   => \$no_cache,
    'json|j'     => \$json,
  );

  my $args = $class->$orig(@args);
  $args->{debug}    = $debug    if $debug;
  $args->{no_cache} = $no_cache if $no_cache;
  $args->{json}     = $json     if $json;

  return $args;
};

has api => (
  is      => 'lazy',
  builder => '_build_api',
);

=attr api

L<WWW::MetaForge::ArcRaiders> instance.

=cut

sub _build_api {
  my ($self) = @_;
  return WWW::MetaForge::ArcRaiders->new(
    debug     => $self->debug,
    use_cache => !$self->no_cache,
  );
}

sub prepare_output {
  my ($self) = @_;
  for my $fh (\*STDOUT, \*STDERR) {
    # a handle that already takes characters keeps its layers; without the
    # check every command run would stack one more :encoding layer
    binmode $fh, ':encoding(UTF-8)'
      unless grep { $_ eq 'utf8' } PerlIO::get_layers($fh, output => 1);
  }
  return;
}

=method prepare_output

    $app->prepare_output;

Every command calls this before it prints. The commands print character
strings, text and JSON alike; this puts an C<:encoding(UTF-8)> layer on
C<STDOUT> and C<STDERR> so they leave the process UTF-8 encoded exactly once,
whether the CLI runs as F<metaforge-arcraiders> or from Perl via
C<new_with_cmd>. A handle that already takes characters (C<:utf8> or any
C<:encoding> layer) is left as it is. The layer stays on the handles after the
command has run.

=cut

sub execute {
  my ($self, $args, $chain) = @_;

  # No subcommand given - show help
  if (!@$chain || @$chain == 1) {
    print "metaforge-arcraiders - CLI for MetaForge ARC Raiders API\n\n";
    print "Usage: metaforge-arcraiders <command> [options]\n\n";
    print "Commands:\n";
    print "  items    List all items (or search)\n";
    print "  item     Show details for a single item\n";
    print "  quests   List all quests\n";
    print "  quest    Show details for a single quest\n";
    print "  arcs     List all ARCs\n";
    print "  arc      Show details for a single arc\n";
    print "  events   Show event timers\n";
    print "  event    Show details for a single event\n";
    print "  traders  List all traders\n";
    print "  trader   Show details for a single trader\n";
    print "  ermal    Show Ermal's offers and permanent services\n";
    print "  hideout  List hideout stations, or show one with its levels\n";
    print "  trials   Show the active and upcoming weekly trials\n";
    print "  map      Show map markers for a map\n";
    print "\nOptions:\n";
    print "  -d, --debug     Enable debug output\n";
    print "  -j, --json      Output as JSON\n";
    print "  --no-cache      Disable caching\n";
    print "\nExamples:\n";
    print "  metaforge-arcraiders items --search Ferro\n";
    print "  metaforge-arcraiders item ferro-i\n";
    print "  metaforge-arcraiders items --page 3\n";
    print "  metaforge-arcraiders quests --all\n";
    print "  metaforge-arcraiders quest a-bad-feeling\n";
    print "  metaforge-arcraiders events\n";
    print "  metaforge-arcraiders trader Apollo\n";
    print "  metaforge-arcraiders ermal\n";
    print "  metaforge-arcraiders hideout gunsmith\n";
    print "  metaforge-arcraiders trials\n";
    print "  metaforge-arcraiders map dam\n";
  }
}

1;
