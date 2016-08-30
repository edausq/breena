package Plugins::When;
use strict qw(subs vars refs);
use warnings;
use POE;
use POE::Component::IRC::Plugin qw( :ALL );
use Convert::Age;
use Time::ParseDate;

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

    if($msg =~ m!^\.when (.*)!)
    {
        my $when = $1;
        $when =~ s/weekend/friday 18h/o;
        $when =~ s/(\d+)h/$1:00/i;
        $when =~ s/:00(\d{2})/:$1/;
        
        my $t = parsedate($when, PREFER_FUTURE => 1, UK => 1);
        my $result;
        if($t)
        {
            $t += 3600*24 if $t < time;
            $result = Convert::Age::encode($t-time());
            $result =~ s/m(.*)/m/;
        }
        else
        {
            $irc->yield(privmsg => $channel => "unable to parse. check http://search.cpan.org/~muir/Time-modules-2003.0211/lib/Time/ParseDate.pm#EXAMPLES");
        }
        if($result)
        {
            $irc->yield(privmsg => $channel => $result);
        }
        else
        {
            $irc->yield(privmsg => $channel => 'I was able to parse but it seems that input is in the past. sorry');
        }
        return PCI_EAT_PLUGIN;
    }

    return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
}

1;
