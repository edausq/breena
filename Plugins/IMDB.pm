package Plugins::IMDB;
use strict qw(subs vars refs);
use warnings;
use POE;
use POE::Component::IRC::Plugin qw( :ALL );
use LWP::UserAgent;
use JSON;
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

    if ($msg =~ /^\.imdb\s(.+)$/)
    {
        my $query = $1;
        my $result = 'internal error';

        my $url = "http://www.imdbapi.com/?t=" . uri_escape($query);
        my $ua = LWP::UserAgent->new(timeout => 5);
        my $response = $ua->get("$url");
        if ($response->is_success)
        {
            my $imdb_json = $response->content;
            my $imdb = from_json($imdb_json);
            if($imdb->{'Response'} eq 'True')
            {
                $result =  "[$imdb->{'Type'}] $imdb->{'Title'} ($imdb->{'Released'}) - $imdb->{'Runtime'} - $imdb->{'Genre'} - $imdb->{'imdbRating'} - http://imdb.com/title/$imdb->{'imdbID'}";
            }
            else
            {
                $result =  "$imdb->{'Error'}";
            }
        }
        else
        {
            $result = $response->status_line;
        }

        $irc->yield(privmsg => $channel => "$result");
        return PCI_EAT_PLUGIN;    # We don't want other plugins to process this
    }
    return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
}

1;
