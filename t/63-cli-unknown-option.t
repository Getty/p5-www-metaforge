#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use JSON::MaybeXS qw(decode_json);
use lib "$FindBin::Bin/lib";

BEGIN {
  eval { require Capture::Tiny };
  if ($@) {
    plan skip_all => 'Capture::Tiny required for CLI tests';
  }
}
use Capture::Tiny qw(capture);

# The global options (--json, --debug, --no-cache, --help) belong in front of
# the command; they are read before the command is picked. An option the
# program or the command does not know is an error: message on STDERR, exit 1,
# nothing on STDOUT and no API request. Swallowing it would hand back text
# where the caller asked for JSON, or an unfiltered list for a misspelled
# filter.

my $fixtures = "$FindBin::Bin/fixtures";

# The real script in a subprocess with the offline LWP shim (answers from the
# fixtures, never the network). RequestLog, written next to the run, appends
# one line per API request to a file, so a test can tell "no request was made"
# from "the request was answered with nothing".
my $request_log_pm = <<'PM';
package RequestLog;
use strict;
use warnings;
use LWP::UserAgent;

my $orig = \&LWP::UserAgent::request;
{
  no warnings 'redefine';
  *LWP::UserAgent::request = sub {
    my ($self, $http_request) = @_;
    if (open my $fh, '>>', $ENV{REQUEST_LOG}) {
      print {$fh} $http_request->uri, "\n";
      close $fh;
    }
    return $orig->($self, $http_request);
  };
}

1;
PM

# returns (stdout, stderr, exit status, number of API requests)
sub run_bin {
  my (@args) = @_;
  my $home = tempdir(CLEANUP => 1);
  my $log  = "$home/requests.log";
  open my $fh, '>', "$home/RequestLog.pm" or die "cannot write RequestLog.pm: $!";
  print {$fh} $request_log_pm;
  close $fh;
  local $ENV{HOME}                              = $home;
  local $ENV{XDG_CACHE_HOME}                    = $home;
  local $ENV{WWW_METAFORGE_ARCRAIDERS_NO_CACHE} = 1;
  local $ENV{OFFLINE_FIXTURES_DIR}              = $fixtures;
  local $ENV{REQUEST_LOG}                       = $log;
  my @perl = ($^X, "-I$FindBin::Bin/../lib", "-I$FindBin::Bin/lib", "-I$home",
    '-MOfflineLWP', '-MRequestLog', "$FindBin::Bin/../bin/metaforge-arcraiders");
  my ($stdout, $stderr, $status) = capture { system @perl, @args };
  my $exit = $status >> 8;
  my $requests = 0;
  if (open my $in, '<', $log) {
    $requests++ while <$in>;
    close $in;
  }
  return ($stdout, $stderr, $exit, $requests);
}

# the command line, the option that must be rejected, extra check on STDERR
my @rejected = (
  [ ['--nope', 'items'], 'nope', 'an unknown option before the command' ],
  [ ['quests', '--type', 'x'], 'type', 'an option the quests command does not have' ],
  [ ['arcs', '--lot'], 'lot', 'a misspelled command option (--loot)' ],
  [ ['items', '--json'], 'json', 'a global option after the command' ],
);

for my $case (@rejected) {
  my ($argv, $option, $what) = @$case;
  subtest "$what is an error: --$option" => sub {
    my ($stdout, $stderr, $exit, $requests) = run_bin(@$argv);
    is($exit, 1, 'exit 1');
    like($stderr, qr/^Unknown option: \Q$option\E$/m, 'STDERR names the option');
    is($stdout, '', 'nothing on STDOUT');
    is($requests, 0, 'no API request was made');
    unlike($stderr, qr/\bat \S+ line \d+/, 'no perl warning or stack trace');
  };
}

subtest 'an unknown option before the command points to --help' => sub {
  my ($stdout, $stderr, $exit) = run_bin('--nope', 'items');
  like($stderr, qr/metaforge-arcraiders --help/, 'STDERR refers to metaforge-arcraiders --help');
};

for my $flag ('--help', '-h') {
  subtest "$flag without a command prints the overview on STDOUT" => sub {
    my ($stdout, $stderr, $exit, $requests) = run_bin($flag);
    is($exit, 0, 'exit 0');
    is($stderr, '', 'nothing on STDERR');
    like($stdout, qr/^Commands:$/m, 'lists the commands');
    like($stdout, qr/^\s*(?:-j, )?--json\b/m, 'lists the --json option');
    is($requests, 0, 'no API request was made');
  };
}

subtest '--json in front of the command gives JSON' => sub {
  my ($stdout, $stderr, $exit, $requests) = run_bin('--json', 'items');
  is($exit, 0, 'exit 0');
  is($stderr, '', 'nothing on STDERR');
  my $data = eval { decode_json($stdout) };
  is(ref $data, 'ARRAY', 'STDOUT decodes to a JSON array');
  ok(scalar @{ $data || [] }, 'the array has records');
  ok($requests > 0, 'the request log sees the API request (the "no request" checks can fail)');
};

done_testing;
