# basic client for authenticated POST and GET
#
# $Id$
# $URL$
#

package Client;

use LWP::UserAgent;
use XML::Twig::XPath;
use Calendar;

sub new {
    my ($class, $adminUser, $adminPasswd, $domain, $service) = @_;
    my $self = bless {
        login        => $adminUser,
        passwd       => $adminPasswd,
        domain       => $domain,
        service      => $service,
        email        => $adminUser . '@' . $domain,
    }, $class;    

    $ua = new LWP::UserAgent;
    $self->{source} = 'apidb.org-:' . __PACKAGE__;

    return $self;
}  


sub authkey() {
    my ($self) = @_;

    return $self->{authkey} if ($self->{authkey} != '');

    $ua->agent("AgentName/0.1 " . $ua->agent);

    my $res = $ua->post(
       'https://www.google.com/accounts/ClientLogin',
       {
         accountType => 'HOSTED_OR_GOOGLE',
         Email       => $self->{email},
         Passwd      => $self->{passwd},
         service     => $self->{service},
         source      => $self->{source},
       }
     );
    
    if ( ! $res->is_success) {
        warn "failed to login to google", $res->status_line, "\n";
        return;
    }
    
    ($self->{authkey}) = $res->content =~ /Auth=(.+)/;
    
    return $self->{authkey};
}

sub auth_header() {
    my ($self) = @_;
    if ( ! $self->authkey) {
        warn "authkey not set\n";
        return;
    }
    return 'Authorization' => "GoogleLogin auth=@{[$self->authkey]}"
}

sub _GET {
    my ($self, $url) = @_;
    my $req = HTTP::Request->new(GET => $url);
    $req->header(Accept => "text/html, */*;q=0.1,", $self->auth_header);
    return $ua->request($req);
}

sub _POST {
    my ($self, $url, $content) = @_;
    my $req = new HTTP::Request POST => $url;

    $req->header(Accept => "text/html, */*;q=0.1,", $self->auth_header);
    $req->content_type('application/atom+xml');
    $req->content($content);
    my $res = $ua->request($req);
    my $redirectCount = 0;
    while ($res->code eq '302' && $redirectCount <= 2) {
        $req = new HTTP::Request POST => $res->header('location');
        $req->header(Accept => "text/html, */*;q=0.1,", $self->auth_header);
        $req->content_type('application/atom+xml');
        $req->content($content);
        $res = $ua->request($req); 
        $redirectCount++;
    }
    return $res;
}


1;
