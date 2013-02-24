use 5.008001;
use strict;
use warnings;

package Dancer2::Session::Memcached;
# ABSTRACT: Dancer 2 session storage with Cache::Memcached
our $VERSION = '0.002'; # VERSION

use Carp;
use Moo;
use Cache::Memcached;
use Dancer2::Core::Types;

#--------------------------------------------------------------------------#
# Public attributes
#--------------------------------------------------------------------------#


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

    return Cache::Memcached->new( servers => $servers );
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


# vim: ts=4 sts=4 sw=4 et:

__END__

=pod

=head1 NAME

Dancer2::Session::Memcached - Dancer 2 session storage with Cache::Memcached

=head1 VERSION

version 0.002

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

=head1 ATTRIBUTES

=head2 memcached_servers (required)

A comma-separated list of reachable memcached servers (can be either
address:port or socket paths).

=for Pod::Coverage method_names_here

=for :stopwords cpan testmatrix url annocpan anno bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/dagolden/dancer2-session-memcached/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/dagolden/dancer2-session-memcached>

  git clone git://github.com/dagolden/dancer2-session-memcached.git

=head1 AUTHOR

David Golden <dagolden@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2013 by David Golden.

This is free software, licensed under:

  The Apache License, Version 2.0, January 2004

=cut
