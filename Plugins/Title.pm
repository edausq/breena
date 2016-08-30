package Plugins::Title;
use strict qw(subs vars refs);
use warnings;
use POE;
use POE::Component::IRC::Plugin qw( :ALL );
use URI::Find;
use LWP::UserAgent;

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

    my $ua = LWP::UserAgent->new(timeout => 5, agent => 'Mozilla/5.0 (X11; Linux x86_64; rv:24.0) Gecko/20140924 Firefox/24.0');
    my $can_accept = HTTP::Message::decodable;
    $ua->max_size(15000000);

    my $finder = URI::Find->new(sub
        {
            my($uri, $orig_uri) = @_;

            my $url = $uri;
            $url =~ m!^http[s]?://! or return;

            my $response = $ua->head($url);
            my $title = '(-)';
            if(defined $response->headers->{refresh})
            {
                $title = 'http refresh: "'.$response->headers->{refresh}.'"';
            }
            elsif($response->content_type() eq 'text/html' or $response->content_type() =~ m!/xml!)
            {
                $response = $ua->get($url, 'Accept-Encoding' => $can_accept);
                if($response->decoded_content(charset => 'none') =~ m!<title>(.*?)</title>!xs)
                {
                    $title = $1;
                }
                else
                {
                    $title = $response->status_line().' (no title)';
                }

            }
            elsif($response->is_success)
            {
                $title = join(' ',$response->header('content-disposition'),$response->content_type)." - ".$response->content_length." octets";
            }
            else
            {
                $title = $response->status_line();
            }
            $irc->yield(privmsg => $channel =>  $title);

        });
    $finder->find(\$msg);
    return PCI_EAT_NONE; # Default action is to allow other plugins to process it.
}

1;
