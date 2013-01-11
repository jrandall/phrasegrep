#!/usr/bin/perl -w 

use strict;
use warnings;

use CGI ':standard';

my $number="";
if(param('number')) {
    $number = param('number');
}

if($number eq "") {
    print header;
    print start_html(-title=>"phonespell");
    print phonespellform();
    print end_html;
} else {
    print header;
    print start_html(-title=>"phonespell");
    print phonespellform();
    print "<HR/>\n";
    print "<P>$number</P>\n";
    print "<HR/>\n";
    print `./phrasegrep.pl -m -i -w scowl-en.20 -p $number`; 
    print end_html;
}

sub phonespellform {
    my $str;
    $str .= "<form action=\"phonespell.pl\" method=\"post\">\n";
    $str .= "<INPUT TYPE=\"text\" NAME=\"number\" VALUE=\"$number\" SIZE=\"64\"/>\n";
    $str .= "<INPUT TYPE=\"submit\" NAME=\"Get Phrases\" VALUE=\"Get Phrases\"/>\n";
    $str .= "</form>\n";
    return($str);
}

sub build_selector {
    my $name = shift;
    my $value = shift;
    my $optionarrayref = shift;
    my @options = @$optionarrayref;
    my $html = "";
    $html .= "<SELECT NAME=\"$name\">\n";
    foreach(@options) {
	my $optval = $_;
	$html .= "   <OPTION VALUE=\"$optval\"";
	if($optval eq $value) {
	    $html .= " SELECTED";
	}
	$html .= ">$optval</OPTION>\n";
    }
    $html .= "</SELECT>\n";
    return($html);
}    


