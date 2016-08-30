package Plugins::Action;
use strict qw(subs vars refs);
use warnings;
use POE;
use POE::Component::IRC::Plugin qw( :ALL );
use Config::Simple;

my $conf_file = "/etc/breena/breena.conf";

my $conf = new Config::Simple("$conf_file") or die "impossible de trouver $conf_file";
my $conf_nick = $conf->param("nick");

# Plugin object constructor
sub new
{
    my ($package) = shift;
    return bless {}, $package;
}

sub PCI_register
{
    my ($self, $irc) = splice @_, 0, 2;
    $irc->plugin_register($self, 'SERVER', qw(ctcp_action));
    return 1;
}

sub PCI_unregister
{
    return 1;
}

sub S_ctcp_action
{
    my ($self, $irc) = splice @_, 0, 2;

# Parameters are passed as scalar-refs including arrayrefs.
    my ($who)    = (split /!/, ${$_[0]})[0];
    my ($channel) = ${$_[1]}->[0];
    my ($msg)     = ${$_[2]};

    if(($msg =~ /^(.*)$conf_nick(.*)$/) && ($who ne 'Mileina'))
    {
        $irc->yield(ctcp => $channel => "ACTION $1$who$2");
        return PCI_EAT_PLUGIN;    # We don't want other plugins to process this
    }
    return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
}

1;
