package Plugins::Bing;
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
my $apikey = $conf->param("bing-api");
# https://datamarket.azure.com/dataset/bing/search

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

    my $request = GET "https://api.datamarket.azure.com/Bing/Search/v1/Web?Query=%27".uri_escape($query)."%27&Market=%27fr-FR%27";
    $request->authorization_basic($apikey, $apikey);
    my $response = $ua->request($request);

    if ($response->is_success)
    {
        my $bing_json = $response->content;
        my $bing = from_json($bing_json);
        if(defined $bing->{d}->{results}[0])
        {
            return $bing->{d}->{results}[0]->{Title} . " - " . $bing->{d}->{results}[0]->{Url};
        }
        else
        {
            return "No results. Try https://duckduckgo.com/?q=".uri_escape($query);
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
        my ($dest,$query) = ($1,$2);
        my $result = search($query);
        $irc->yield(privmsg => $channel => "$result");
        return PCI_EAT_PLUGIN;    # We don't want other plugins to process this
    }
    return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
}

1;
