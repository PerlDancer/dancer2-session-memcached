use 5.008001;
use strict;
use warnings;

package Dancer2::Session::Memcached;
# ABSTRACT: Dancer 2 session storage with Cache::Memcached
# VERSION

use Carp;
use Moo;
use Cache::Memcached;
use Dancer2::Core::Types;

#--------------------------------------------------------------------------#
# Public attributes
#--------------------------------------------------------------------------#

=attr memcached_servers (required)

A comma-separated list of reachable memcached servers (can be either
address:port or socket paths).

=cut

has memcached_servers => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has fatal_cluster_unreachable => (
    is       => 'ro',
    isa      => Bool,
    required => 0,
    default  => sub { 0 },
);

#--------------------------------------------------------------------------#
# Private attributes
#--------------------------------------------------------------------------#

has _memcached => (
    is  => 'lazy',
    isa => InstanceOf ['Cache::Memcached'],
    handles => {
        _retrieve => 'get',
        _flush => 'set',
        _destroy => 'delete',
    },
);

# Adapted from Dancer::Session::Memcached
sub _build__memcached {
    my ($self) = @_;

    my $servers = $self->memcached_servers;

    croak "The setting memcached_servers must be defined"
      unless defined $servers;

    $servers = [ split /,\s*/, $servers ];

    # make sure the servers look good
    foreach my $s (@$servers) {
        if ( $s =~ /^\d+\.\d+\.\d+\.\d+$/ ) {
            croak "server `$s' is invalid; port is missing, use `server:port'";
        }
    }

    my $cache_engine = Cache::Memcached->new( servers => $servers );

    croak "Memcache cluster unreachable"
        if $self->fatal_cluster_unreachable && not keys %{$cache_engine->stats(['misc'])};

    return $cache_engine;
}

#--------------------------------------------------------------------------#
# Role composition
#--------------------------------------------------------------------------#

with 'Dancer2::Core::Role::SessionFactory';

# _retrieve, _flush, _destroy handled by _memcached object

# memcached doesn't have any easy way to list keys it knows about
# so we cheat and return an empty array ref
sub _sessions {
    my ($self) = @_;
    return [];
}

1;

=for Pod::Coverage method_names_here

=head1 SYNOPSIS

  # In Dancer 2 config.yml file

  session: Memcached
  engines:
    session:
      Memcached:
        memcached_servers: 10.0.1.31:11211,10.0.1.32:11211,/var/sock/memcached

=head1 DESCRIPTION

This module implements a session factory for Dancer 2 that stores session
state within Memcached using L<Cache::Memcached>.

=cut

# vim: ts=4 sts=4 sw=4 et:
