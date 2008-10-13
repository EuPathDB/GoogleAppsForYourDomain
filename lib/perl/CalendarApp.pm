# Manage Google Calendar App.
#
# $Id$
# $URL$
#

package CalendarApp;

use strict;
use Client;
use Data::Dumper;
use Util;

my $client;
my @allcalendars;

sub new {
    my ($class, $adminUser, $adminPasswd, $domain) = @_;
    $client = new Client($adminUser, $adminPasswd, $domain, 'cl');
    my $self = bless {}, $class;
    return $self;
}  


sub retrieveAllCalendars {
    $_[0]->_retrieveCalendars('allcalendars');
}

sub retrieveOwnCalendars {
    $_[0]->_retrieveCalendars('owncalendars');
}

sub retrieveCalendarFromAll {
    my ($self, $calendarName) = @_;
    for my $calendar ($self->retrieveAllCalendars) {
        return $calendar if ($calendar->calendarName eq $calendarName);
    }
}

sub _retrieveCalendars {
    my ($self, $which) = @_;

    return  @{$self->{$which}} if $self->{$which};

    my $allCalUrl = "http://www.google.com/calendar/feeds/default/$which/full";
    my $feed = $client->_GET($allCalUrl)->content;
    $self->{$which} = Util::_feedToEntries(\$feed, 'Calendar', $client);
    return @{$self->{$which}};
}





1;
