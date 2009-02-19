#
# $Id$
# $URL$
#

package Util;

use strict;
use XML::Twig;
use XML::Twig::XPath;


sub _feedToEntries {
    my ($feed, $className, @other) = @_;
    my @entries;
    my $twig= new XML::Twig::XPath( 
        twig_handlers => { 'entry' => 
            sub { push @entries, $className->new($_[1], @other) } 
        },
        pretty_print => 'record',
        keep_atts_order => 1,
      );
    $twig->parse($$feed);
    return \@entries;
}


sub _attrValueForFirstPath {
    my ($twig, $att, $path) = @_;
    my ($elt) = $twig->findnodes($path);
    my $txt = $elt->{'att'}->{$att};
    $twig->purge;
    return $txt;
}
sub _firstValueForFirstPath {
    my ($twig, $path) = @_;
    my ($elt) = $twig->findnodes($path);
    my $txt = $elt->first_child_text;
    $twig->purge;
    return $txt;
}



1;
