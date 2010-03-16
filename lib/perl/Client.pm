# basic client for authenticated POST and GET
#
# $Id$
# $URL$
#

package Client;

use LWP::UserAgent;
use XML::Twig::XPath;
use Calendar;
use Document;

my $DEBUG = 0;

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
    return $self->{authkey} if (defined $self->{authkey} && $self->{authkey} ne '');

    $ua->agent("AgentName/0.1 " . $ua->agent);

    if ($self->{service} eq 'wise') {
       $url = 'https://spreadsheets.google.com/accounts/ClientLogin';
    } else {
       $url = 'https://www.google.com/accounts/ClientLogin';
    }

    my $res = $ua->post(
       $url,
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

    $DEBUG && warn "authkey: " . $self->{authkey} . "\n";

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

# code pilfered from lwp-download
sub _GETFILE {
    my ($self, $url, $directory, $filename) = @_;

    $filename =~ s/([^a-zA-Z0-9_\.\-\+\~\ \?])/sprintf "%%%02x", ord($1)/ge;

    my $file;
    my $length;
    my $size;

    my $req = HTTP::Request->new(GET => $url);
    $req->header(Accept => "text/html, */*;q=0.1,", $self->auth_header);
    
    my $res = $ua->request($req,
      sub {
        unless (defined $file) {
            my $res = $_[1];
            $file = $filename;
            if (defined $directory) {
                require File::Spec;
                $file = File::Spec->catfile($directory, $file);
            }

            $DEBUG && print "saving to $file\n";
            $DEBUG && print "unlinking $file\n";

            unlink $file if (-f $file);
            open(FILE, ">$file") || die "Can't open $file: $!\n";
            binmode FILE;
        }
        print FILE $_[0] or die "Can't write to $file: $!\n";
        $size += length($_[0]);
      }
    );

    if (fileno(FILE)) {
      close(FILE) || die "Can't write to $file: $!\n";
    }

    if (my $xdied = $res->header("X-Died")) {
        print "\nAborted\n$xdied\n";
    }
}

1;
