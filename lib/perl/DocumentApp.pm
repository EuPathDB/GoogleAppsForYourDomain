# Manage Google Document App.
#
# $Id: DocumentApp.pm 24133 2008-10-13 13:24:33Z mheiges $
# $URL$
#

package DocumentApp;

use strict;
use Client;
use Data::Dumper;
use Util;

my $client;
my @alldocuments;

my $DEBUG = 1;

sub new {
    my ($class, $adminUser, $adminPasswd, $domain) = @_;
    my $service = 'writely';
    $client = new Client($adminUser, $adminPasswd, $domain, $service);
    my $self = bless {}, $class;
    return $self;
}  


sub retrieveAllDocuments {
    $_[0]->_retrieveDocumentList('private');
}

sub retrieveOwnDocuments {
    # currently no distinction from all documents
    $_[0]->_retrieveDocumentList('/-/mine');
}

sub retrieveDocumentFromAll {
    my ($self, $documentName) = @_;
    for my $document ($self->retrieveAllDocuments) {
        return $document if ($document->documentName eq $documentName);
    }
}

sub _retrieveDocumentList {
    my ($self, $whose) = @_;

    return  @{$self->{$whose}} if $self->{$whose};

    my $allDocUrl = "http://docs.google.com/feeds/documents/private/full$whose";

    $DEBUG && warn "GETting $allDocUrl\n";
    
    my $req = $client->_GET($allDocUrl);
    if ($req->is_success) {
      my $feed = $req->content;
      $self->{$whose} = Util::_feedToEntries(\$feed, 'Document', $client);
      return @{$self->{$whose}};
    }
    die "Failed: " . $req->status_line . "\nfor '$allDocUrl'\n";
    return undef;
}


sub export {
    my ($self, $document, $format) = @_;
    my $type = $document->type;
    my $exportUrl = 'http://docs.google.com/feeds/download/' .
                     $type . 's/Export?docID=' . $document->id .
                    '&exportFormat=' . $format;
    my $directory = '/tmp';
    my $filename = $document->title;
    $client->_GETFILE($exportUrl, $directory, $filename);
}





1;
