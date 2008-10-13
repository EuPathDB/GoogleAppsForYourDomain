# One calendar in Calendar App.
#
# $Id$
# $URL$
#

package Calendar;

use strict;
use XML::Twig::XPath;
use Util;
use Data::Dumper;

sub new {
    my ($class, $entryTwigElt, $calAppClient) = @_;
    my $entryTwig = new XML::Twig::XPath();
    $entryTwig->parse($entryTwigElt->toString);
    my $self = bless {
        entryTwig => $entryTwig,
        calAppClient => $calAppClient,
    }, $class;
    
    return $self;
}  

sub calendarName { $_[0]->authorName }
sub authorName {
    my ($self) = @_;
    return Util::_firstValueForFirstPath($self->{'entryTwig'}, '/entry/author/name');
}

sub acl {
    $_[0]->{'calAppClient'}->_GET($_[0]->aclUrl)->content;
}

sub aclUserEmails {
    my ($self) = @_;
    my $aclFeed = $self->acl;
    use XML::Simple;
    my @users;
    my $acl = XMLin($aclFeed, ForceArray => 0);
    for my $url (keys %{$acl->{'entry'}}) {
       push @users, $acl->{'entry'}->{$url}->{'gAcl:scope'}->{'value'} . "\n"
        if $acl->{'entry'}->{$url}->{'gAcl:scope'}->{'type'} eq 'user';
    }
    return @users;
}

# add email addr to ACL
# returns POST result; e.g. can use $res->content or $res->code to check success
sub addUserToAcl {
    my ($self, $email) = @_;
    my $acl = <<"ACL";
<entry xmlns='http://www.w3.org/2005/Atom' xmlns:gAcl='http://schemas.google.com/acl/2007'>
  <category scheme='http://schemas.google.com/g/2005#kind'
    term='http://schemas.google.com/acl/2007#accessRule'/>
  <gAcl:scope type='user' value='$email'></gAcl:scope>
  <gAcl:role
    value='http://schemas.google.com/gCal/2005#editor'>
  </gAcl:role>
</entry>
ACL
    my $res = $self->{'calAppClient'}->_POST($self->aclUrl, $acl);
    return $res;
}

sub aclUrl {
    my ($self) = @_;
    return Util::_attrValueForFirstPath(
      $self->{'entryTwig'},
      'href', 
      '/entry/link[@rel="http://schemas.google.com/acl/2007#accessControlList"]'
    );
}

sub editUrl {
    my ($self) = @_;
    return Util::_attrValueForFirstPath(
      $self->{'entryTwig'},
      'href', 
      '/entry/link[@rel="edit"]'
    );
}

sub xml {
    $_[0]->{entryTwig}->toString;
}




1;




__END__

<entry>
  <id>http://www.google.com/calendar/feeds/default/allcalendars/full/apidb.org_j3jjr7qn2m536pcssa0v13p5r8%40group.calendar.google.com</id>
  <published>2008-10-12T04:57:50.405Z</published>
  <updated>2008-10-10T17:05:06.000Z</updated>
  <title type="text">People</title>
  <summary type="text">Where are they now?</summary>
  <content type="application/atom+xml" src="http://www.google.com/calendar/feeds/apidb.org_j3jjr7qn2m536pcssa0v13p5r8%40group.calendar.google.com/private/full"/>
  <link rel="alternate" type="application/atom+xml" href="http://www.google.com/calendar/feeds/apidb.org_j3jjr7qn2m536pcssa0v13p5r8%40group.calendar.google.com/private/full"/>
  <link rel="http://schemas.google.com/acl/2007#accessControlList" type="application/atom+xml" href="http://www.google.com/calendar/feeds/apidb.org_j3jjr7qn2m536pcssa0v13p5r8%40group.calendar.google.com/acl/full"/>
  <link rel="self" type="application/atom+xml" href="http://www.google.com/calendar/feeds/default/allcalendars/full/apidb.org_j3jjr7qn2m536pcssa0v13p5r8%40group.calendar.google.com"/>
  <link rel="edit" type="application/atom+xml" href="http://www.google.com/calendar/feeds/default/allcalendars/full/apidb.org_j3jjr7qn2m536pcssa0v13p5r8%40group.calendar.google.com"/>
  <author>
    <name>People</name>
  </author>
  <gCal:timezone value="America/New_York"/>
  <gCal:timesCleaned value="0"/>
  <gCal:hidden value="false"/>
  <gCal:color value="#7A367A"/>
  <gCal:selected value="true"/>
  <gCal:accesslevel value="root"/>
  <gd:where valueString=""/>
</entry>
