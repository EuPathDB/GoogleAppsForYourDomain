# One document in Document App.
#
# $Id: Document.pm 24133 2008-10-13 13:24:33Z mheiges $
# $URL$
#

package Document;

use strict;
use XML::Twig::XPath;
use Util;
use Data::Dumper;

sub new {
    my ($class, $entryTwigElt, $docAppClient) = @_;
    my $entryTwig = new XML::Twig::XPath();
    $entryTwig->parse($entryTwigElt->toString);
    my $self = bless {
        entryTwig => $entryTwig,
        docAppClient => $docAppClient,
    }, $class;
    
    return $self;
}  

sub documentName { $_[0]->title }
sub authorName {
    my ($self) = @_;
    return Util::_firstValueForFirstPath($self->{'entryTwig'}, '/entry/author/name');
}

sub acl {
    $_[0]->{'docAppClient'}->_GET($_[0]->aclUrl)->content;
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

    warn "not tested\n"; return;
    
    my ($self, $email) = @_;
    my $acl = <<"ACL";
<entry xmlns='http://www.w3.org/2005/Atom' xmlns:gAcl='http://schemas.google.com/acl/2007'>
  <category scheme='http://schemas.google.com/g/2005#kind'
    term='http://schemas.google.com/acl/2007#accessRule' />
  <gAcl:scope type='user' value='$email' />
  <gAcl:role value='writer' />
</entry>
ACL
    my $res = $self->{'docAppClient'}->_POST($self->aclUrl, $acl);
    return $res;
}

sub aclUrl {
    my ($self) = @_;
    return Util::_attrValueForFirstPath(
      $self->{'entryTwig'},
      'href', 
      '/entry/gd:feedLink[@rel="http://schemas.google.com/acl/2007#accessControlList"]'
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

sub type {
    my ($self) = @_;
    return Util::_attrValueForFirstPath(
      $self->{'entryTwig'},
      'label', 
      '/entry/category[@scheme="http://schemas.google.com/g/2005#kind"]'
    );
}

sub id {
    my ($self) = @_;
    my $idUrl = Util::_firstValueForFirstPath(
      $self->{'entryTwig'},
      '/entry/id'
    );
    my ($id) = $idUrl =~ m/^.+?%3A(.+)$/;
    return $id; 
}

sub title {
    my ($self) = @_;
    return Util::_firstValueForFirstPath(
      $self->{'entryTwig'},
      '/entry/title'
    );
}

sub updated {
    my ($self) = @_;
    return Util::_firstValueForFirstPath(
      $self->{'entryTwig'},
      '/entry/updated'
    );
}

sub published {
    my ($self) = @_;
    return Util::_firstValueForFirstPath(
      $self->{'entryTwig'},
      '/entry/published'
    );
}

sub xml {
    $_[0]->{entryTwig}->toString;
}




1;




__END__

<entry>
  <id>http://docs.google.com/feeds/documents/private/full/spreadsheet%3ApXNXTWOumD5F6jU_Mh3OZGg</id>
  <published>2006-06-06T07:00:00.000Z</published>
  <updated>2007-10-19T15:45:23.342Z</updated>
  <category label="spreadsheet" scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/docs/2007#spreadsheet"/>
  <title type="text">PlasmoDB_QA</title>
  <content src="http://spreadsheets.google.com/feeds/download/spreadsheets/Export?fmcmd=102&amp;key=pXNXTWOumD5F6jU_Mh3OZGg" type="text/html"/>
  <link href="http://spreadsheets.google.com/a/apidb.org/ccc?key=pXNXTWOumD5F6jU_Mh3OZGg" rel="alternate" type="text/html"/>
  <link href="http://spreadsheets.google.com/feeds/worksheets/pXNXTWOumD5F6jU_Mh3OZGg/private/values" rel="http://schemas.google.com/spreadsheets/2006#worksheetsfeed" type="application/atom+xml"/>
  <link href="http://docs.google.com/feeds/documents/private/full/spreadsheet%3ApXNXTWOumD5F6jU_Mh3OZGg" rel="self" type="application/atom+xml"/>
  <link href="http://docs.google.com/feeds/documents/private/full/spreadsheet%3ApXNXTWOumD5F6jU_Mh3OZGg/f7yvilce" rel="edit" type="application/atom+xml"/>
  <link href="http://docs.google.com/feeds/media/private/full/spreadsheet%3ApXNXTWOumD5F6jU_Mh3OZGg/f7yvilce" rel="edit-media" type="text/html"/>
  <author>
    <name>brunkb</name>
    <email>brunkb@apidb.org</email>
  </author>
</entry>
