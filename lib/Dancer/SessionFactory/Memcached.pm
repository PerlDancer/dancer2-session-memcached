use 5.008001;
use strict;
use warnings;

package Dancer::SessionFactory::Memcached;
# ABSTRACT: Dancer 2 session storage with Memcached
# VERSION

use Carp;
use Moo;
use Cache::Memcached;
use Dancer::Core::Types;

#--------------------------------------------------------------------------#
# Public attributes
#--------------------------------------------------------------------------#

=attr database_name (required)

Name of the database to hold the sessions collection.

=cut

has memcached_servers => (
    is       => 'ro',
    isa      => Str,
    required => 1,
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

    return Cache::Memcached->new( servers => $servers );
}

#--------------------------------------------------------------------------#
# Role composition
#--------------------------------------------------------------------------#

with 'Dancer::Core::Role::SessionFactory';

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
        memcached_servers: "10.0.1.31:11211,10.0.1.32:11211,/var/sock/memcached

=head1 DESCRIPTION

This module implements a session factory for Dancer 2 that stores session
state within Memcached.

=cut

# vim: ts=4 sts=4 sw=4 et:
