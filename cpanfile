
requires 'Moo', '2.0';
requires 'Type::Tiny', '1.0';
requires 'LWP::UserAgent', '6.0';
requires 'JSON::MaybeXS', '1.0';
requires 'HTTP::Request', '6.0';
requires 'Path::Tiny', '0.100';
requires 'Digest::MD5', '0';
requires 'URI', '1.0';
requires 'namespace::clean', '0.27';
requires 'MooX::Cmd', '0.017';

on test => sub {
  requires 'Test::More', '1.302015';
};
