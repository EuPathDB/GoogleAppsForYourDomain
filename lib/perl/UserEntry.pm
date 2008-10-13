# One user in Google Apps For Your Domain
#
# $Id$
# $URL$
#

package UserEntry;

use strict;
use XML::Twig::XPath;
use Data::Dumper;

sub new {
    my ($class, $entryTwigElt) = @_;
    my $entryTwig = new XML::Twig::XPath();
    $entryTwig->parse($entryTwigElt->toString);
    my $self = bless {
        entryTwig => $entryTwig,
    }, $class;
    
    $self->_parseEntry();
    
    return $self;
}  


sub userName {
    $_[0]->{'userName'}
}

sub suspended {
    $_[0]->{'suspended'}
}

sub ipWhitelisted {
    $_[0]->{'ipWhitelisted'}
}

sub admin {
    $_[0]->{'admin'}
}

sub changePasswordAtNextLogin {
    $_[0]->{'changePasswordAtNextLogin'}
}

sub agreedToTerms {
    $_[0]->{'agreedToTerms'}
}


sub xml {
    $_[0]->{entryTwig}->toString;
}


sub _parseEntry {
    $_[0]->_parseAppsLogin($_[0]->{'entryTwig'}->findnodes('//entry/apps:login'));
}

sub _parseAppsLogin {
    my ($self, $appsLogin) = @_;
    for my $att (keys %{$appsLogin->{att}}) {
        $self->{$att} = $appsLogin->{att}->{$att};
    }
}

1;




__END__


<entry xmlns="http://www.w3.org/2005/Atom" xmlns:apps="http://schemas.google.com/apps/2006" xmlns:gd="http://schemas.google.com/g/2005">
  <id>https://apps-apis.google.com/a/feeds/apidb.org/user/2.0/weili1</id>
  <updated>1970-01-01T00:00:00.000Z</updated>
  <category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/apps/2006#user"/>
  <title type="text">weili1</title>
  <link rel="self" type="application/atom+xml" href="https://apps-apis.google.com/a/feeds/apidb.org/user/2.0/weili1"/>
  <link rel="edit" type="application/atom+xml" href="https://apps-apis.google.com/a/feeds/apidb.org/user/2.0/weili1"/>
  <apps:login userName="weili1" suspended="false" ipWhitelisted="false" admin="false" changePasswordAtNextLogin="false" agreedToTerms="true"/>
  <apps:quota limit="7168"/>
  <apps:name familyName="Li" givenName="Wei"/>
  <gd:feedLink rel="http://schemas.google.com/apps/2006#user.nicknames" href="https://apps-apis.google.com/a/feeds/apidb.org/nickname/2.0?username=weili1"/>
  <gd:feedLink rel="http://schemas.google.com/apps/2006#user.emailLists" href="https://apps-apis.google.com/a/feeds/apidb.org/emailList/2.0?recipient=weili1%40apidb.org"/>
</entry>
