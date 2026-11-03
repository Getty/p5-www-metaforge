
requires 'DateTime';
requires 'Digest::MD5';
requires 'HTTP::Message';
requires 'JSON::MaybeXS', '1.000000';
requires 'LWP::Protocol::https';
requires 'LWP::UserAgent';
requires 'Moo';
requires 'MooX::Cmd';
requires 'MooX::Options';
requires 'namespace::clean';
requires 'Path::Tiny', '0.043';
requires 'Type::Tiny';
requires 'Types::Standard';
requires 'URI';

on test => sub {
  requires 'Capture::Tiny';
  requires 'Test::More';
};
