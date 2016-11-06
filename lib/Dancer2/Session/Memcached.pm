use strict;
use warnings;

package Dancer2::Session::Memcached;
# ABSTRACT: Dancer 2 session storage with Cache::Memcached
# VERSION
our $VERSION = '0.004';

use Moo;
use Cache::Memcached;

use Types::Standard qw/ Str ArrayRef InstanceOf /;

use Type::Tiny;

my $Server = Type::Tiny->new(
    name       => 'MemcachedServer',
    parent     => Str,
    constraint => sub { ! /^\d+\.\d+\.\d+\.\d+$/ },
    message    => sub {
        "server `$_' is invalid; port is missing, use `server:port'"
    },

);

my $Servers = Type::Tiny->new(
    name     => 'MemcachedServers',
    parent   => ArrayRef[$Server],
    coercion => Type::Coercion->new( type_coercion_map => [
        Str ,=> sub { [ split ',', $_ ] },
    ]),
);


#--------------------------------------------------------------------------#
# Public attributes
#--------------------------------------------------------------------------#

=attr memcached_servers (required)

An array (or a comma-separated list) of reachable memcached 
servers (can be either address:port or socket paths).

=cut

has memcached_servers => (
    is       => 'ro',
    isa      => $Servers,
    required => 1,
    coerce   => $Servers->coercion,
);

#--------------------------------------------------------------------------#
# Private attributes
#--------------------------------------------------------------------------#

has _memcached => (
    is  => 'lazy',
    isa => InstanceOf ['Cache::Memcached'],
    handles => {
        _retrieve => 'get',
        _flush    => 'set',
        _destroy  => 'delete',
    },
);

# Adapted from Dancer::Session::Memcached
sub _build__memcached {
    my ($self) = @_;
    return Cache::Memcached->new( servers => $self->memcached_servers );
}

#--------------------------------------------------------------------------#
# Role composition
#--------------------------------------------------------------------------#

with 'Dancer2::Core::Role::SessionFactory';

# _retrieve, _flush, _destroy handled by _memcached object

# memcached doesn't have any easy way to list keys it knows about
# so we cheat and return an empty array ref
sub _sessions { [] }

sub _change_id {
    my ( $self, $old_id, $new_id ) = @_;
    $self->_flush( $new_id, $self->_retrieve( $old_id ) );
    $self->_destroy( $old_id );
}

1;

=for Pod::Coverage method_names_here

=head1 SYNOPSIS

  # In Dancer 2 config.yml file

  session: Memcached
  engines:
    session:
      Memcached:
        memcached_servers: 
          - 10.0.1.31:11211
          - 10.0.1.32:11211
          - /var/sock/memcached

=head1 DESCRIPTION

This module implements a session factory for L<Dancer2> that stores session
state within Memcached using L<Cache::Memcached>.

=cut

# vim: ts=4 sts=4 sw=4 et:
