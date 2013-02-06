use Mojo::Base -strict;

use Test::More;
use Mango::Protocol;

# Generate next id
my $protocol = Mango::Protocol->new;
is $protocol->next_id(1),          2,          'right id';
is $protocol->next_id(2147483646), 2147483647, 'right id';
is $protocol->next_id(2147483647), 1,          'right id';

# Build minimal update
is $protocol->build_update(1, 'foo', {}, {}, {}),
    "\x26\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\xd1\x07\x00\x00\x00\x00"
  . "\x00\x00\x66\x6f\x6f\x00\x00\x00\x00\x00\x05\x00\x00\x00\x00\x05\x00\x00"
  . "\x00\x00", 'minimal update';

# Build minimal insert
is $protocol->build_insert(1, 'foo', {}, {}),
  "\x1d\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\xd2\x07\x00\x00\x00\x00"
  . "\x00\x00\x66\x6f\x6f\x00\x05\x00\x00\x00\x00", 'minimal insert';

# Build minimal query
is $protocol->build_query(1, 'foo', {}, 0, 10, {}, {}),
    "\x2a\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\xd4\x07\x00\x00\x00\x00"
  . "\x00\x00\x66\x6f\x6f\x00\x00\x00\x00\x00\x0a\x00\x00\x00\x05\x00\x00\x00"
  . "\x00\x05\x00\x00\x00\x00", 'minimal query';

# Build minimal get_more
is $protocol->build_get_more(1, 'foo', 10, 1),
  "\x24\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\xd5\x07\x00\x00\x00\x00"
  . "\x00\x00\x66\x6f\x6f\x00\x0a\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00",
  'minimal get_more';

# Build minimal delete
is $protocol->build_delete(1, 'foo', {}, {}),
  "\x21\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\xd6\x07\x00\x00\x00\x00"
  . "\x00\x00\x66\x6f\x6f\x00\x00\x00\x00\x00\x05\x00\x00\x00\x00",
  'minimal delete';

# Build minimal kill_cursors
is $protocol->build_kill_cursors(1, 1),
  "\x20\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\xd7\x07\x00\x00\x00\x00"
  . "\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00",
  'minimal kill_cursors';

# Parse full reply with leftovers
my $buffer
  = "\x51\x00\x00\x00\x69\xaa\x04\x00\x03\x00\x00\x00\x01\x00\x00\x00\x08\x00"
  . "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00"
  . "\x2d\x00\x00\x00\x02\x6e\x6f\x6e\x63\x65\x00\x11\x00\x00\x00\x33\x32\x39"
  . "\x35\x65\x35\x63\x64\x35\x65\x65\x66\x32\x35\x30\x30\x00\x01\x6f\x6b\x00"
  . "\x00\x00\x00\x00\x00\x00\xf0\x3f\x00\x51";
my $reply = $protocol->parse_reply(\$buffer);
is $buffer, "\x51", 'right leftovers';
my $nonce = {
  id     => 305769,
  to     => 3,
  flags  => {await_capable => 1, query_failure => 0, cursor_not_found => 0},
  cursor => 0,
  from   => 0,
  docs => [{nonce => '3295e5cd5eef2500', ok => 1}]
};
is_deeply $reply, $nonce, 'right reply';

# Parse partial reply
my $before = my $after = "\x10";
is $protocol->parse_reply(\$after), undef, 'nothing';
is $before, $after, 'no changes';
$before = $after = "\x00\x01\x00\x00";
is $protocol->parse_reply(\$after), undef, 'nothing';
is $before, $after, 'no changes';

# Parse wrong message type
$buffer = $protocol->build_insert(1, 'foo', {}, {}) . "\x00";
is $protocol->parse_reply(\$buffer), undef, 'nothing';
is $buffer, "\x00", 'message has been removed';

done_testing();