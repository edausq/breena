package Plugins::Google;
use strict qw(subs vars refs);
use warnings;
use POSIX qw(strftime);
use POE;
use POE::Component::IRC::Plugin qw( :ALL );
use LWP::UserAgent;
use HTTP::Request::Common qw(GET);
use Config::Simple;
use JSON;
use URI::Escape;

my $conf_file = "/etc/breena/breena.conf";

my $conf = new Config::Simple("$conf_file") or die "impossible de trouver $conf_file";
my $searchid = $conf->param("google-search-id");
my $apikey = $conf->param("google-search-api");
# https://developers.google.com/custom-search/json-api/v1/using_rest

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

sub search
{
    my ($query) = @_;
    my $ua = LWP::UserAgent->new(timeout => 5);
    $ua->default_header('Accept' => 'application/json');

    my $request = GET "https://www.googleapis.com/customsearch/v1?key=".$apikey."&cx=".$searchid."&q=".uri_escape($query)."&num=1";
    my $response = $ua->request($request);

    if ($response->is_success)
    {
        my $google_json = $response->content;
        my $google = from_json($google_json);
        if(defined $google->{items}[0])
        {
            return $google->{items}[0]->{title} . " - " . $google->{items}[0]->{link};
        }
        else
        {
            return "No results. Try https://www.google.com/search?q=/?q=".uri_escape($query);
        }
    }
    else
    {
        return $response->status_line;
    }
}

sub S_public
{
    my ($self, $irc) = splice @_, 0, 2;

# Parameters are passed as scalar-refs including arrayrefs.
    my ($who)    = (split /!/, ${$_[0]})[0];
    my ($channel) = ${$_[1]}->[0];
    my ($msg)     = ${$_[2]};

    if ($msg =~ /^\.g\s(.+)$/)
    {
        my $result = search($1);
        $irc->yield(privmsg => $channel => "$result");
        return PCI_EAT_PLUGIN;    # We don't want other plugins to process this
    }
    return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
}

1;
