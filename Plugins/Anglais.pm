package Plugins::Anglais;
use strict qw(subs vars refs);
use warnings;
use POE;
use POE::Component::IRC::Plugin qw( :ALL );
use LWP::UserAgent;

my ($dirpath) = (__FILE__ =~ m{^(.*/)?.*}s);

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

    if ($msg =~ /^\.anglais (.*)/)
    {
        my $ua = LWP::UserAgent->new(timeout => 5);
        my $url = "http://www.anglais-conjugaison.com/search?verb=$1";
        my $response = $ua->get($url);
        if ($response->is_success)
        {
            my $forms = $response->content;
            if($forms =~ m!<div class="fb-like" data-href="(.*?)"!s)
            {
                $url = $1;
            }

            if($forms =~ m!<div class="info">.*?<br/>(.*?)<br/>.*?</div>!s)
            {
                my $tmp = $1;
                $tmp =~ s/ //g;
                $tmp =~ s/\n//g;
                $tmp =~ s/,/ - /g;
                $url = "$url ($tmp)";
            }
        }
        else
        {
            $irc->yield(privmsg => $channel => $response->status_line);
        }
        $irc->yield(privmsg => $channel => "$url");

        return PCI_EAT_PLUGIN;    # We don't want other plugins to process this
    }
    return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
}

1;
