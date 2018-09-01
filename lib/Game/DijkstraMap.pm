# -*- Perl -*-
#
# a numeric grid of weights plus some related functions
#
# run perldoc(1) on this file for additional documentation

package Game::DijkstraMap;

use 5.010000;
use strict;
use warnings;

use Carp qw(croak);
use Moo;
use namespace::clean;
use Scalar::Util qw(looks_like_number);

our $VERSION = '0.02';

has max_cost => ( is => 'rw', default => sub { ~0 } );
has min_cost => ( is => 'rw', default => sub { 0 } );
has bad_cost => ( is => 'rw', default => sub { -1 } );
has costfn   => (
    is      => 'rw',
    default => sub {
        return sub {
            my ( $self, $c ) = @_;
            if ( $c eq '#' ) { return $self->bad_cost }
            if ( $c eq 'x' ) { return $self->min_cost }
            return $self->max_cost;
        };
    },
);
has dimap => ( is => 'rw', );
has iters => ( is => 'rwp', default => sub { 0 } );

sub map {
    my ( $self, $map ) = @_;
    my $dimap = [];
    croak "no valid map supplied"
      if !defined $map
      or ref $map ne 'ARRAY'
      or !defined $map->[0]
      or ref $map->[0] ne 'ARRAY';
    my $cols = @{ $map->[0] };
    for my $r ( 0 .. $#$map ) {
        croak "unexpected column count at row $r" if @{ $map->[$r] } != $cols;
        for my $c ( 0 .. $cols - 1 ) {
            $dimap->[$r][$c] = $self->costfn->( $self, $map->[$r][$c] );
        }
    }
    $self->normalize_costs($dimap);
    $self->dimap($dimap);
    return $self;
}

sub normalize_costs {
    my ( $self, $dimap ) = @_;
    my $badcost = $self->bad_cost;
    my $maxcost = $self->max_cost;
    my $iters   = 0;
    while (1) {
        my $stable = 1;
        $iters++;
        my $maxrow = $#$dimap;
        my $maxcol = $#{ $dimap->[0] };
        for my $r ( 0 .. $maxrow ) {
            for my $c ( 0 .. $maxcol ) {
                my $value = $dimap->[$r][$c];
                next if $value == $badcost;
                my $min = $maxcost;
                my $tmp;
                if ( $c > 0 ) {
                    $tmp = $dimap->[$r][ $c - 1 ];
                    $min = $tmp if $tmp != $badcost and $tmp < $min;
                }
                if ( $c < $maxcol ) {
                    $tmp = $dimap->[$r][ $c + 1 ];
                    $min = $tmp if $tmp != $badcost and $tmp < $min;
                }
                if ( $r > 0 ) {
                    $tmp = $dimap->[ $r - 1 ][$c];
                    $min = $tmp if $tmp != $badcost and $tmp < $min;
                }
                if ( $r < $maxrow ) {
                    $tmp = $dimap->[ $r + 1 ][$c];
                    $min = $tmp if $tmp != $badcost and $tmp < $min;
                }
                if ( $value > $min + 2 ) {
                    $dimap->[$r][$c] = $min + 1;
                    $stable = 0;
                }
            }
        }
        last if $stable;
    }
    $self->_set_iters($iters);
    return $self;
}

sub str2map {
    my ( $self_or_class, $str, $lf ) = @_;
    croak "no string given" if !defined $str;
    $lf //= $/;
    my @map;
    for my $line ( split $lf, $str ) {
        push @map, [ split //, $line ];
    }
    return \@map;
}

sub recalc {
    my ($self) = @_;
    my $dimap = $self->dimap;
    croak "cannot recalc unset map" if !defined $dimap;
    my $maxcost = $self->max_cost;
    my $mincost = $self->min_cost;
    my $maxcol  = $#{ $dimap->[0] };
    for my $r ( 0 .. $#$dimap ) {
        for my $c ( 0 .. $maxcol ) {
            $dimap->[$r][$c] = $maxcost if $dimap->[$r][$c] > $mincost;
        }
    }
    $self->normalize_costs($dimap);
    $self->dimap($dimap);
    return $self;
}

sub update {
    my $self  = shift;
    my $dimap = $self->dimap;
    croak "cannot update unset map" if !defined $dimap;
    my $maxrow = $#$dimap;
    my $maxcol = $#{ $dimap->[0] };
    for my $ref (@_) {
        my ( $r, $c ) = ( $ref->[0], $ref->[1] );
        croak "row $r out of bounds" if $r > $maxrow or $r < 0;
        croak "col $c out of bounds" if $c > $maxcol or $c < 0;
        croak "value must be a number" unless looks_like_number $ref->[2];
        $dimap->[$r][$c] = int $ref->[2];
    }
    $self->dimap($dimap);
    return $self;
}

1;
__END__

=head1 NAME

Game::DijkstraMap - a numeric grid of weights plus some related functions

=head1 SYNOPSIS

  use Game::DijkstraMap;
  my $dm = Game::DijkstraMap->new;

  # x is where the player is (the goal) and the rest are
  # considered as walls or floor tiles (see the costfn)
  my $level = Game::DijkstraMap->str2map(<<'EOM');
  #########
  #.h.....#
  #.#####'#
  #.#####x#
  #########
  EOM

  # create the dijkstra map
  $dm->map($level);

  # change the open door ' to a closed one
  $dm->update( [ 2, 7, -1 ] );
  $dm->recalc;

=head1 DESCRIPTION

This module implements code described by "The Incredible Power of
Dijkstra Maps" article. Such maps have various uses in roguelikes or
other games. This implementation may not be fast but should allow quick
prototyping of map-building and path-finding exercises.

L<http://www.roguebasin.com/index.php?title=The_Incredible_Power_of_Dijkstra_Maps>

The L</CONSIDERATIONS> section describes what this module does in
more detail.

=head1 CONSTRUCTOR

The B<new> method accepts the L</ATTRIBUTES> in the usual L<Moo>
fashion.

=head1 ATTRIBUTES

=over 4

=item B<max_cost>

Cost for non-goal non-wall points. A large number by default. These
points should be reduced to appropriate weights (steps from the nearest
goal point) by B<normalize_costs>.

=item B<min_cost>

Cost for points that are goals (there can be multiple goals on a grid).
Zero by default.

=item B<bad_cost>

Cost for cells through which motion is illegal (walls, typically, though
a map for cats may also treat water as impassable). C<-1> by default,
and ignored when updating the map. This value for optimization purposes
is assumed to be lower than B<min_cost>.

=item B<costfn>

A code reference called with the object and each cell of the I<map>
passed to B<map>. This function must convert the contents of the cell
into suitable cost numbers for the Dijkstra Map. Defaults to a function
that assigns B<bad_cost> to C<#> (walls), B<min_cost> to C<x> (goals),
and otherwise B<max_cost> for what is assumed to be floor tiles.

If the I<map> is instead a grid of objects, there may need to be a
suitable method call in those objects that returns the cost of what the
cell contains that a custom B<costfn> then calls.

=item B<dimap>

The Dijkstra Map, presently an array reference of array references of
integer values. Do not change this reference unless you know what you
are doing. It can also be assigned to directly, for better or worse.

Must not be accessed by calls to B<recalc> or B<update> before being set
by the B<map> method (or manually).

=item B<iters>

This is set after the B<map> and B<recalc> method calls and indicates
how many iterations it took B<normalize_costs> to stabilize the map.

=back

=head1 METHODS

These methods will throw exceptions if something goes awry (especially
when given known bad input).

=over 4

=item B<map> I<map>

Accepts a level map (an array reference of array references, or a 2D
grid) and uses the B<costfn> to convert the objects in that I<map> to
the internal Dijkstra Map that is held in the B<dimap> attribute.

Returns the object so can be chained with other calls.

=item B<normalize_costs> I<dimap>

Mostly an internal routine called by B<map> or B<update> that reduces
B<max_cost> cells as appropriate relative to the connected
B<min_cost> cells. Changes the B<iters> attribute.

=item B<str2map> I<string> [ I<split-with> ]

Utility method that converts string maps to a form suitable to be passed
to the B<map> method. Without the optional I<split-with> argument the
string will be split into lines using C<$/>.

=item B<recalc>

Resets the weights of all non-wall non-goal cells and then calls
B<normalize_costs>. See below for a discussion of B<update> and
B<recalc>.

Returns the object so can be chained with other calls.

=item B<update> I<[row, col, value]> ..

Updates the given row and column with the given value for each array
reference passed. Does not recalculate the weights; see below for a
longer discussion.

Returns the object so can be chained with other calls.

=back

=head1 CONSIDERATIONS

Given the map where C<h> represents a hound, C<@> our doomed yet somehow
still optimistic hero, C<'> an open door, and so forth,

    012345678
  -+--------- turn 1
  0|#########
  1|#h......#
  2|#.#####'#
  3|#.#####@#
  4|#########

A Dijkstra Map with the player as the only goal would be the following
grid of integers that outline the corridor leading to the player

     0  1  2  3  4  5  6  7  8
  -+--------------------------
  0|-1|-1|-1|-1|-1|-1|-1|-1|-1
  1|-1| 8| 7| 6| 5| 4| 3| 2|-1
  2|-1| 9|-1|-1|-1|-1|-1| 1|-1
  3|-1|10|-1|-1|-1|-1|-1| 0|-1
  4|-1|-1|-1|-1|-1|-1|-1|-1|-1

which allows the hound to move towards the player by trotting down the
positive integers, or to flee by going the other way. This map may need
to be updated when the player moves or changes the map; for example the
player could close the door:

  ######### turn 2
  #..h....#
  #.#####+#
  #.#####@#
  #########

This change can be handled in various ways. A door may be as a wall to a
hound, so updated to be one

  $map->update( [ 2, 7, $map->bad_cost ] );

results in the map

     0  1  2  3  4  5  6  7  8
  -+--------------------------
  0|-1|-1|-1|-1|-1|-1|-1|-1|-1
  1|-1| 8| 7| 6| 5| 4| 3| 2|-1
  2|-1| 9|-1|-1|-1|-1|-1|-1|-1
  3|-1|10|-1|-1|-1|-1|-1| 0|-1
  4|-1|-1|-1|-1|-1|-1|-1|-1|-1

and a hound waiting outside the door, ready to spring (or maybe it gets
bored and wanders off, depending on the monster AI and how much patience
our hero has). The situation could also be handled by not updating the
map and code outside of this module handling the hound/closed door
interaction.

The B<recalc> method may be necessary where due to the closed door there
is a new and longer path around to the player that should be followed:

  #########      turn 2 (door was closed on turn 1)
  #....h..#
  #.#####+#########
  #.#####@........#
  #.#############.#
  #...............#
  #################

  $map->update(...)           # case 1
  $map->update(...)->recalc;  # case 2

Case 1 would have the hound move to the door while case 2 would instead
cause the hound to move around the long way. If the door after case 2 is
opened and only an B<update> is done, the new shorter route would only
be considered by monsters directly adjacent to the now open door (weight
path 34, 1, 0 and also 33, 1, 0 if diagonal moves are permitted) and not
those at 32, 31, etc. along the longer route; for those to see the
change of the door another B<recalc> would need to be done.

If you know all the cells that are floor tiles these could be passed to
B<update> after the map changes or the player moves; this may be less
expensive than B<recalc> as that must inspect each cell in the grid.

=head1 BUGS

=head2 Reporting Bugs

Please report any bugs or feature requests to
C<bug-game-dijkstramap at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Game-DijkstraMap>.

Patches might best be applied towards:

L<https://github.com/thrig/Game-DijkstraMap>

=head2 Known Issues

New code. Need to add path finding (routes) and next cell (steps along
routes) methods.

B<normalize_costs> is not very good with long and mostly unconnected
corridors; this could be improved on by considering adjacent unseen
cells after a cell changes in addition to full map iterations.

=head1 SEE ALSO

There are various other graph and path finding modules on CPAN that may
be more suitable to the task at hand.

=head1 AUTHOR

thrig - Jeremy Mates (cpan:JMATES) C<< <jmates at cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 by Jeremy Mates

This program is distributed under the (Revised) BSD License:
L<http://www.opensource.org/licenses/BSD-3-Clause>

=cut
