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

my $docClient;
my $spreadSheetClient;
my @alldocuments;

my $DEBUG = 0;

sub new {
    my ($class, $adminUser, $adminPasswd, $domain) = @_;
    $docClient = new Client($adminUser, $adminPasswd, $domain, 'writely');
    $spreadSheetClient = new Client($adminUser, $adminPasswd, $domain, 'wise');
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

    $DEBUG && warn "GET $allDocUrl\n";
    
    my $req = $docClient->_GET($allDocUrl);
    if ($req->is_success) {
      my $feed = $req->content;
      $self->{$whose} = Util::_feedToEntries(\$feed, 'Document', $docClient);
      return @{$self->{$whose}};
    }
    die "Failed: " . $req->status_line . "\nfor '$allDocUrl'\n";
    return undef;
}


sub export {
    my ($self, $document, $format, $directory) = @_;
    my $type = $document->type;
    
    my %fmcmd = (
      'xls'  => 4,
      'csv'  => 5,
      'pdf'  => 12,
      'ods'  => 13,
      'tsv'  => 23,
      'html' => 102,
    );

    my %expUrls = (
      'document' => 'http://docs.google.com/feeds/download/' .
                     $type . 's/Export?docID=' . $document->id .
                    '&exportFormat=' . $format,

      'presentation' => 'http://docs.google.com/feeds/download/' .
                        $type . 's/Export?docID=' . $document->id .
                       '&exportFormat=' . $format,

      'spreadsheet' => 'http://spreadsheets.google.com/feeds/download/' .
                        $type . 's/Export?key=' . $document->id .
                       '&fmcmd=' . ($fmcmd{$format} || ''),
    );
    
    my $filename = $document->title . '.' . $format;

    $DEBUG && warn "exporting to $filename\n";
    $DEBUG && warn "from " . $expUrls{$type} . "\n";

    if ($type eq 'spreadsheet') {
        $spreadSheetClient->_GETFILE($expUrls{$type}, $directory, $filename);
    } else {
        $docClient->_GETFILE($expUrls{$type}, $directory, $filename);
    }
}





1;
