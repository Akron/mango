use Mojo::Base -strict;

use Test::More;
use List::Util 'first';
use Mango;
use Mojo::IOLoop;

plan skip_all => 'set TEST_ONLINE to enable this test'
  unless $ENV{TEST_ONLINE};

# Defaults
my $mango = Mango->new;
is_deeply $mango->hosts, [['localhost']], 'right hosts';
is $mango->default_db, 'admin', 'right default database';
is_deeply $mango->credentials, [], 'no credentials';
is $mango->j,        0,    'right j value';
is $mango->w,        1,    'right w value';
is $mango->wtimeout, 1000, 'right wtimeout value';

# Simple connection string
$mango = Mango->new('mongodb://127.0.0.1:3000');
is_deeply $mango->hosts, [['127.0.0.1', 3000]], 'right hosts';
is $mango->default_db, 'admin', 'right default database';
is_deeply $mango->credentials, [], 'no credentials';
is $mango->j,        0,    'right j value';
is $mango->w,        1,    'right w value';
is $mango->wtimeout, 1000, 'right wtimeout value';

# Complex connection string
$mango = Mango->new(
  'mongodb://x1:y2@foo.bar:5000,baz:3000/test?journal=1&w=2&wtimeoutMS=2000');
is_deeply $mango->hosts, [['foo.bar', 5000], ['baz', 3000]], 'right hosts';
is $mango->default_db, 'test', 'right default database';
is_deeply $mango->credentials, [[qw(test x1 y2)]], 'right credentials';
is $mango->j,        1,    'right j value';
is $mango->w,        2,    'right w value';
is $mango->wtimeout, 2000, 'right wtimeout value';
is $mango->db->name, 'test', 'right database name';

# Invalud connection string
eval { Mango->new('http://localhost:3000/test') };
like $@, qr/Invalid MongoDB connection string/, 'right error';

# No port
$mango = Mango->new('mongodb://127.0.0.1,127.0.0.1:5000');
is_deeply $mango->hosts, [['127.0.0.1'], ['127.0.0.1', 5000]], 'right hosts';

# Cleanup before start
$mango = Mango->new($ENV{TEST_ONLINE});
my $collection = $mango->db->collection('connection_test');
$collection->drop
  if first { $_ eq 'connection_test' } @{$mango->db->collection_names};

# Blocking CRUD
my $oid = $collection->insert({foo => 'bar'});
isa_ok $oid, 'Mango::BSON::ObjectID', 'right class';
my $doc = $collection->find_one({foo => 'bar'});
is_deeply $doc, {_id => $oid, foo => 'bar'}, 'right document';
$doc->{foo} = 'yada';
is $collection->update({foo => 'bar'}, $doc), 1, 'one document updated';
$doc = $collection->find_one($oid);
is_deeply $doc, {_id => $oid, foo => 'yada'}, 'right document';
is $collection->remove, 1, 'one document removed';

# Non-blocking CRUD
my ($fail, $created, $updated, $found, $removed);
my $delay = Mojo::IOLoop->delay(
  sub {
    my $delay = shift;
    $collection->insert({foo => 'bar'} => $delay->begin);
  },
  sub {
    my ($delay, $err, $oid) = @_;
    $fail    = $err;
    $created = $oid;
    $collection->find_one({foo => 'bar'} => $delay->begin);
  },
  sub {
    my ($delay, $err, $doc) = @_;
    $fail ||= $err;
    $doc->{foo} = 'yada';
    $collection->update(({foo => 'bar'}, $doc) => $delay->begin);
  },
  sub {
    my ($delay, $err, $num) = @_;
    $fail ||= $err;
    $updated = $num;
    $collection->find_one($created => $delay->begin);
  },
  sub {
    my ($delay, $err, $doc) = @_;
    $fail ||= $err;
    $found = $doc;
    $collection->remove($delay->begin);
  },
  sub {
    my ($delay, $err, $num) = @_;
    $fail ||= $err;
    $removed = $num;
  }
);
$delay->wait;
ok !$fail, 'no error';
isa_ok $created, 'Mango::BSON::ObjectID', 'right class';
is $updated, 1, 'one document updated';
is_deeply $found, {_id => $created, foo => 'yada'}, 'right document';
is $removed, 1, 'one document removed';

done_testing();
