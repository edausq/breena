package Plugins::TVRage;
use strict qw(subs vars refs);
use warnings;
use POE;
use POE::Component::IRC::Plugin qw( :ALL );
use LWP::UserAgent;
use URI::Escape;

# Plugin object constructor
sub new
{
    my ($package) = shift;
    return bless {}, $package;
}

sub PCI_register
{
    my ($self, $irc) = splice @_, 0, 2;
    $irc->plugin_register($self, 'SERVER', qw(public));
    return 1;
}

sub PCI_unregister
{
    return 1;
}

sub S_public
{
    my ($self, $irc) = splice @_, 0, 2;

# Parameters are passed as scalar-refs including arrayrefs.
    my ($who)    = (split /!/, ${$_[0]})[0];
    my ($channel) = ${$_[1]}->[0];
    my ($msg)     = ${$_[2]};

    if ($msg =~ /^!(n|l)\s(.+)$/)
    {
        my $q = $1;
        my $query = $2;
        my $result = 'internal error';

        my %var;
        $var{l} = 'latest';
        $var{n} = 'next';

        my $url = 'http://services.tvrage.com/feeds/episodeinfo.php?show=' . uri_escape($query);
        my $ua = LWP::UserAgent->new(timeout => 5);
        my $response = $ua->get("$url");

        if ($response->is_success)
        {
            my $tvrage_xml = $response->content;

            if($tvrage_xml =~ m!<show id='(.+?)'><name>(.+?)</name><link>(.+?)</link>.+?<$var{$q}episode><number>(.+?)</number><title>(.+?)</title><airdate>(.+?)</airdate>!)
            {
                $result = "$var{$q} episode of $2 is $4 - $5 (airdate: $6) $3";
            }
            elsif($tvrage_xml =~ /(No Show Results Were Found For.*?")$/)
            {
                $result = $1;
            }
            elsif($tvrage_xml =~ m!<name>(.+?)</name><link>(.+?)</link>.+?<ended>(.+)</ended>!)
            {
                $result = "$1 ended on $3 $2";
            }
            elsif($tvrage_xml =~ m!<name>(.+?)</name><link>(.+?)</link>.+?<status>(.+)</status>!)
            {
                $result = "$1 is $3 $2 (debug: $url)";
            }
        }
        else
        {
            $result = "api tvrage: ".$response->status_line." (debug: $url)";
        }

        $irc->yield(privmsg => $channel => "$result");
        return PCI_EAT_PLUGIN;    # We don't want other plugins to process this
    }
    return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
}

1;
