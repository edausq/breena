﻿package Plugins::Time;
use strict qw(subs vars refs);
use warnings;
use POSIX qw(strftime);
use POE;
use POE::Component::IRC::Plugin qw( :ALL );
use Config::Simple;
use LWP::UserAgent;
use JSON;

my $conf_file = "/etc/breena/breena.conf";

my $conf = new Config::Simple("$conf_file") or die "impossible de trouver $conf_file";
my $conf_google_api = $conf->param("google-api");

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

    if ($msg =~ /^time (.+)$/)
    {
        my $address = $1;
        $address =~ s/\s//g;
        my $now_string = "Data not found.";
        my $ua = LWP::UserAgent->new(timeout => 5);
        my $response = $ua->get("https://maps.googleapis.com/maps/api/geocode/json?address=".$address."&sensor=false&language=fr&region=fr&api=".$conf_google_api);
        if ($response->is_success)
        {
            my $geocode = from_json($response->content);
            if($geocode->{'status'} eq 'OK')
            {
                my $loc = $geocode->{'results'}[0]->{'geometry'}->{'location'};
                my $req = "https://maps.googleapis.com/maps/api/timezone/json?location=".$loc->{'lat'}.",".$loc->{'lng'}."&timestamp=".strftime("%s",gmtime())."&sensor=false&language=fr&api=".$conf_google_api;
                my $response = $ua->get($req);
                if ($response->is_success)
                {
                    my $timezone = from_json($response->content);
                    if($timezone->{'status'} eq 'OK')
                    {
                        $now_string = strftime "%a %b %e %H:%M:%S %Y", gmtime(time + $timezone->{'rawOffset'} + $timezone->{'dstOffset'});
                        $now_string = $timezone->{'timeZoneId'} . ": " . $now_string;
                    }
                    else
                    {
                        $now_string = $timezone->{'status'};
                    }
                }
                else
                {
                    $now_string = $response->status_line;
                }
            }
            else
            {
                $now_string = $geocode->{'status'};
            }
        }
        else
        {
            $now_string = $response->status_line;
        }
        $irc->yield(privmsg => $channel => "$now_string ($address)");
        return PCI_EAT_PLUGIN;    # We don't want other plugins to process this
    }
    return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
}

1;
