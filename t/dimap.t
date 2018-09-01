#!perl

use strict;
use warnings;

use Test::Most;    # plan is down at bottom
my $deeply = \&eq_or_diff;

use Game::DijkstraMap;
my $map = Game::DijkstraMap->new;

dies_ok( sub { $map->map("treasure") }, 'R.L.S. called' );
dies_ok( sub { $map->recalc }, 'recalc not allowed before map is set' );
dies_ok(
    sub { $map->update( [ 0, 0, 42 ] ) },
    'update not allowed before map is set'
);

is( $map->max_cost, ~0 );
is( $map->min_cost, 0 );
is( $map->bad_cost, -1 );
ok( ref $map->costfn eq 'CODE' );

is( $map->iters, 0 );

$map->map( [ [qw(. . .)], [qw(. . .)], [qw(. . x)] ] );
$deeply->( $map->dimap, [ [qw(4 3 2)], [qw(3 2 1)], [qw(2 1 0)] ] );
is( $map->iters, 5 );

# TODO probably instead use is_deeply and then call this as the default
# eq_or_diff output can be hard to read for grids, or figure out
# something better from Test::Differences to use...
#diag display $map->dimap;
sub display {
    my ($map) = @_;
    my $s = $/;
    for my $r ( 0 .. $#$map ) {
        for my $c ( 0 .. $#{ $map->[0] } ) {
            $s .= $map->[$r][$c] . "\t";
        }
        $s .= $/;
    }
    $s .= $/;
    return $s;
}

my $level = $map->str2map(<<'EOM');
,#####,
##...##
#..#.x#
##...##
,#####,
EOM
$deeply->(
    $level,
    [   [ ",", "#", "#", "#", "#", "#", "," ],
        [ "#", "#", ".", ".", ".", "#", "#" ],
        [ "#", ".", ".", "#", ".", "x", "#" ],
        [ "#", "#", ".", ".", ".", "#", "#" ],
        [ ",", "#", "#", "#", "#", "#", "," ],
    ]
);

$deeply->(
    $map->map($level)->dimap,
    [   [ ~0, -1, -1, -1, -1, -1, ~0 ],
        [ -1, -1, 4,  3,  2,  -1, -1 ],
        [ -1, 6,  5,  -1, 1,  0,  -1 ],
        [ -1, -1, 4,  3,  2,  -1, -1 ],
        [ ~0, -1, -1, -1, -1, -1, ~0 ],
    ]
);

$map->update( [ 2, 1, 0 ] );

$deeply->(
    $map->dimap,
    [   [ ~0, -1, -1, -1, -1, -1, ~0 ],
        [ -1, -1, 4,  3,  2,  -1, -1 ],
        [ -1, 0,  5,  -1, 1,  0,  -1 ],
        [ -1, -1, 4,  3,  2,  -1, -1 ],
        [ ~0, -1, -1, -1, -1, -1, ~0 ],
    ]
);

$map->recalc;

$deeply->(
    $map->dimap,
    [   [ ~0, -1, -1, -1, -1, -1, ~0 ],
        [ -1, -1, 2,  3,  2,  -1, -1 ],
        [ -1, 0,  1,  -1, 1,  0,  -1 ],
        [ -1, -1, 2,  3,  2,  -1, -1 ],
        [ ~0, -1, -1, -1, -1, -1, ~0 ],
    ]
);

plan tests => 14;
