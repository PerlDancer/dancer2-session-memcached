use strict;
use warnings;
use Test::More;
use Test::TCP 1.13;

use JSON;
use File::Temp 0.22;
use HTTP::Date qw/str2time/;
use LWP::UserAgent;
use Cache::Memcached;

sub extract_cookie {
    my ($res) = @_;
    my @cookies = $res->header('set-cookie');
    for my $c (@cookies) {
        next unless $c =~ /dancer\.session/;
        my @parts = split /;\s+/, $c;
        my %hash =
          map { my ( $k, $v ) = split /\s*=\s*/; $v ||= 1; ( lc($k), $v ) } @parts;
        $hash{expires} = str2time( $hash{expires} )
          if $hash{expires};
        return \%hash;
    }
    return;
}

my $client = eval {
    my $m = Cache::Memcached->new( servers => ["127.0.0.1:11211"] );
    $m->set("hello", "world");
    my $got = $m->get("hello") || '';
    $got eq 'world' ? $m : undef;
};

plan skip_all => "No memcached on localhost:11211"
    unless $client;

# make sure we clean up from prior runs
$client->flush_all;

my $tempdir = File::Temp::tempdir( CLEANUP => 1, TMPDIR => 1 );

my $engine = "Memcached";

Test::TCP::test_tcp(
    client => sub {
        my $port = shift;

        my $ua = LWP::UserAgent->new;
        $ua->cookie_jar( { file => "$tempdir/cookies.txt" } );

        # no session cookie set if session not referenced
        my $res = $ua->get("http://127.0.0.1:$port/no_session_data");
        ok $res->is_success, "/no_session_data"
          or diag explain $res;
        my $cookie = extract_cookie($res);
        ok !$cookie, "no cookie set"
          or diag explain $cookie;

        # no session created if session read attempted
        $res = $ua->get("http://127.0.0.1:$port/read_session");
        ok $res->is_success, "/read_session";
        $cookie = extract_cookie($res);
        ok !$cookie, "no cookie set"
          or diag explain $cookie;
        like $res->content, qr/name=''/, "empty session";

        # set value into session
        $res = $ua->get("http://127.0.0.1:$port/set_session/larry");
        ok $res->is_success, "/set_session/larry";
        $cookie = extract_cookie($res);
        ok $cookie, "session cookie set"
          or diag explain $cookie;
        my $sid1 = $cookie->{"dancer.session"};

        # read value back
        $res = $ua->get("http://127.0.0.1:$port/read_session");
        ok $res->is_success, "/read_session";
        $cookie = extract_cookie($res);
        ok $cookie, "session cookie set"
          or diag explain $cookie;
        like $res->content, qr/name='larry'/, "session value looks good";

        # session cookie should persist even if we don't touch sessions
        $res = $ua->get("http://127.0.0.1:$port/no_session_data");
        ok $res->is_success, "/no_session_data";
        $cookie = extract_cookie($res);
        ok $cookie, "session cookie set"
          or diag explain $cookie;

        # destroy session and check that cookies expiration is set
        $res = $ua->get("http://127.0.0.1:$port/destroy_session");
        ok $res->is_success, "/destroy_session";
        $cookie = extract_cookie($res);
        ok $cookie, "session cookie set"
          or diag explain $cookie;
        is $cookie->{"dancer.session"}, $sid1, "correct cookie expired";
        ok $cookie->{expires} < time, "session cookie is expired";

        # shouldn't be sent session cookie after session destruction
        $res = $ua->get("http://127.0.0.1:$port/no_session_data");
        ok $res->is_success, "/no_session_data";
        $cookie = extract_cookie($res);
        ok !$cookie, "no cookie set"
          or diag explain $cookie;

        # set value into session again
        $res = $ua->get("http://127.0.0.1:$port/set_session/curly");
        ok $res->is_success, "/set_session/larry";
        $cookie = extract_cookie($res);
        ok $cookie, "session cookie set"
          or diag explain $cookie;
        my $sid2 = $cookie->{"dancer.session"};
        isnt $sid2, $sid1, "New session has different ID";

        # destroy and create a session in one request
        $res = $ua->get("http://127.0.0.1:$port/churn_session");
        ok $res->is_success, "/churn_session";
        $cookie = extract_cookie($res);
        ok $cookie, "session cookie set"
          or diag explain $cookie;
        my $sid3 = $cookie->{"dancer.session"};
        isnt $sid3, $sid2, "Changed session has different ID";

        # read value back
        $res = $ua->get("http://127.0.0.1:$port/read_session");
        ok $res->is_success, "/read_session";
        $cookie = extract_cookie($res);
        ok $cookie, "session cookie set"
          or diag explain $cookie;
        like $res->content, qr/name='damian'/, "session value looks good";

        # create separate session
        $ua->cookie_jar( { file => "$tempdir/cookies2.txt" } );
        $res = $ua->get("http://127.0.0.1:$port/set_session/moe");
        ok $res->is_success, "/set_session/larry";

        $res = $ua->get("http://127.0.0.1:$port/dump_session");
        my $dump = from_json( $res->content );
        $cookie = extract_cookie($res);
        my $sid4 = $cookie->{"dancer.session"};
        is_deeply(
            $dump,
            {
                id   => $sid4,
                data => { name => 'moe' },
                is_dirty => 0,
            },
            "session dump correct"
        );

        File::Temp::cleanup();
    },
    server => sub {
        my $port = shift;

        use Dancer2;

        get '/no_session_data' => sub {
            return "session not modified";
        };

        get '/set_session/*' => sub {
            my ($name) = splat;
            session name => $name;
        };

        get '/read_session' => sub {
            my $name = session('name') || '';
            "name='$name'";
        };

        get '/destroy_session' => sub {
            my $name = session('name') || '';
            context->destroy_session;
            return "destroyed='$name'";
        };

        get '/churn_session' => sub {
            context->destroy_session;
            session name => 'damian';
            return "churned";
        };

        get '/list_sessions' => sub {
            return to_json( engine("session")->sessions );
        };

        get '/dump_session' => sub {
            return to_json( { %{ session() } } );
        };

        setting appdir => $tempdir;
        setting(
            engines => {
                session => {
                    $engine => {
                        memcached_servers => '127.0.0.1:11211',
                    }
                }
            }
        );
        setting( session => $engine );

        set(
            show_errors  => 1,
            startup_info => 0,
            environment  => 'production',
            port         => $port
        );

        Dancer2->runner->server->port($port);
        start;
    },
);

done_testing;

# vim: ts=4 sts=4 sw=4 et:
