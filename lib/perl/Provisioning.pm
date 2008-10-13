# Manage users in Google Apps For Your Domain
#
# $Id$
# $URL$
#

package Provisioning;


use strict;
use XML::Twig;
use Client;
use UserEntry;
use Util;

my $client;

sub new {
    my ($class, $adminUser, $adminPasswd, $domain) = @_;
    $client = new Client($adminUser, $adminPasswd, $domain, 'apps');
    my $self = bless {
        domain => $domain,
    }, $class;
    return $self;
}  


sub retrieveUser {
    my ($self, $username) = @_;
    my $feed = $client->_GET( "https://apps-apis.google.com/a/feeds/@{[$self->{domain}]}/user/2.0/$username" )->content;
    my $ar = Util::_feedToEntries(\$feed, 'UserEntry');
    return wantarray ? @$ar : $ar->[0];
}

sub retrieveAllUsers {
    my ($self) = @_;

    my $feed = $client->_GET( "https://apps-apis.google.com/a/feeds/@{[$self->{domain}]}/user/2.0" )->content;
    return @{Util::_feedToEntries(\$feed, 'UserEntry')};
}


sub retrievePageOfUsers {
    my ($self, $startUsername) = @_;
}

1;
