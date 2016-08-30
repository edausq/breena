package Plugins::Meteo;
use strict qw(subs vars refs);
use warnings;
use POSIX qw(strftime);
use POE;
use POE::Component::IRC::Plugin qw( :ALL );
use Config::Simple;
use LWP::UserAgent;
use JSON;

my ($dirpath) = (__FILE__ =~ m{^(.*/)?.*}s);
my $conf_file = "/etc/breena/breena.conf";

my $conf = new Config::Simple("$conf_file") or die "impossible de trouver $conf_file";
my $conf_api = $conf->param("openweathermap-api");

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

    if ($msg =~ /^meteo (.+)$/)
    {
        my $city = $1;
        $city =~ s/\s/%20/g;
        my $weather_string = "Data not found.";
        my $ua = LWP::UserAgent->new(timeout => 5);
        my $response = $ua->get("http://api.openweathermap.org/data/2.5/find?APPID=$conf_api&q=$city");
        if ($response->is_success)
        {
            my $weather_json = $response->content;
            my $weather = from_json($weather_json);
            if($weather->{cod} eq '200')
            {
                my $last_update = int((time - $weather->{'list'}[0]->{'dt'})/60);
                my $temp_celcius = int($weather->{'list'}[0]->{'main'}->{'temp'} - 273.15);
                $weather_string = "$last_update minutes ago in $weather->{'list'}[0]->{'name'} ($weather->{'list'}[0]->{'sys'}->{'country'}): $weather->{'list'}[0]->{'weather'}[0]->{'description'}, $temp_celcius℃. humidity: $weather->{'list'}[0]->{'main'}->{'humidity'}%. cloudiness: $weather->{'list'}[0]->{'clouds'}->{'all'}%. wind speed: $weather->{'list'}[0]->{'wind'}->{'speed'}mps. pressure: $weather->{'list'}[0]->{'main'}->{'pressure'}hPa. http://openweathermap.org/city/$weather->{'list'}[0]->{'id'}";
            }
        }
        else
        {
            $irc->yield(privmsg => $channel => $response->status_line);
        }
        $irc->yield(privmsg => $channel => "$weather_string");
        return PCI_EAT_PLUGIN;    # We don't want other plugins to process this
    }
    return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
}

1;
