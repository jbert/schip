#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 31;

BEGIN { use_ok('Schip::Env'); }

my $env = Schip::Env->new;
ok(!$env->pop_frame(), "can't pop frames on empty env");
is($env->frame_depth, 0, "no frames in env");

is($env->lookup('foo'), undef, "can't find foo");
ok($env->push_frame(foo => 'fooval'), "can push frame");
is($env->frame_depth, 1, "now one frame");
is($env->lookup('foo'), 'fooval', "now can find foo");

ok($env->push_frame(bar => 'barval'), "can push another frame");
is($env->frame_depth, 2, "now two frames");
is($env->lookup('foo'), 'fooval', "still can find foo");
is($env->lookup('bar'), 'barval', "now can find bar");

my $cloned_env = $env->clone;
ok($cloned_env, "can get cloned env");

is($cloned_env->frame_depth, 2, "two frames in cloned env");
is($cloned_env->lookup('foo'), 'fooval', "can find foo in clone");
is($cloned_env->lookup('bar'), 'barval', "can find bar in clone");

ok($env->push_frame(foo => 'newfooval'), "can push frame to shadow foo");
is($env->frame_depth, 3, "now three frames");
is($env->lookup('foo'), 'newfooval', "can find shadowed value for foo");
is($env->lookup('bar'), 'barval', "can still find bar");

is($cloned_env->frame_depth, 2, "still only two frames in cloned env");
is($cloned_env->lookup('foo'), 'fooval', "can find unshadowed foo in clone");
is($cloned_env->lookup('bar'), 'barval', "can find bar in clone");


ok(!$env->lookup('defined'), "'defined' not there at first");
ok(!$cloned_env->lookup('defined'), "'defined' not in cloned env either");
ok($env->add_define('defined', 'badger'), "can define a val");
ok($env->lookup('defined'), "'defined' now there");
ok($cloned_env->lookup('defined'), "'defined' now in cloned env");

ok(!$env->lookup('defined2'), "'defined2' not there at first");
ok($env->add_define('defined2', 'badger2'), "can define another val");
ok($env->lookup('defined2'), "'defined2' now there");
ok($env->lookup('defined'), "'defined' still there");
