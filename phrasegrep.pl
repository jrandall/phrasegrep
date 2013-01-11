#!/usr/bin/perl -w 
# phrasegrep.pl: Grep for phrases in addition to single words.

use strict;
use warnings;

# Globals
use vars qw/ %opt /;
#use vars qw/ $debugfh /;
#use vars qw/ $verbose /;
#use vars qw/ @patterns /;
my $debugfh;
my $wordlistfh;
my $verbose;
my $htmlout;
my $printinc;
my @wordlist;
my @patterns;
my %matchcache;
my %phonespell = (
		  0 => "[\\w]",
		  1 => "[\\w]",
		  2 => "[abc]",
		  3 => "[def]",
		  4 => "[ghi]",
		  5 => "[jkl]",
		  6 => "[mno]",
		  7 => "[pqrs]",
		  8 => "[tuv]",
		  9 => "[wxyz]"
		  );


# Get command-line options
# All remaining arguments contains a regular-expression pattern for each character of the phrase or word to grep for.  *, +, and {} modifiers should only be used carefully, as they will drastically increase running time and will ONLY MATCH WITHIN A WORD.  For normal use, each character should have it's own pattern.
sub init() {
    use Getopt::Std;
    my $opt_string = 'hmdiv:n:w:p:c:r';
    getopts( "$opt_string", \%opt) or usage();
    usage() if $opt{'h'};
    if(($opt{'c'} && $opt{'r'}) || ($opt{'p'} && $opt{'r'}) || ($opt{'c'} && $opt{'p'})) {
	print "You can only use one of -r, -p, and -c at a time.\n";
    }
    usage() if(!$opt{'w'});
 
    if($opt{'i'}) {
	$printinc = 1;
    } else {
	$printinc = 0;
    }

    if($opt{'m'}) {
	$htmlout = 1;
    } else {
	$htmlout = 0;
    }
    
    if($opt{'d'}) {
	$debugfh = *STDERR;
    } else {
	$debugfh = *STDOUT;
    }
    
    if($opt{'v'}) {
	if($opt{'v'} eq "") {
	    $verbose = 2;
	} else {
	    $verbose = $opt{'v'};
	}
	debug(2,"Verbose mode on.\n");
    } else {
	$verbose = 0;
    }

    @patterns = ();

    if($opt{'p'}) {
	debug(3,"processing phonespell number: ".$opt{'p'}."\n");
	foreach my $digit ( $opt{'p'} =~ m/\d/g ) {
	    my $pattern = $phonespell{$digit};
	    debug(3,"pattern ".@patterns."=$pattern\n");
	    push @patterns,$pattern;
	}
    }

    if($opt{'c'}) {
	debug(3,"processing character set string: ".$opt{'c'}."\n");
	foreach my $pattern ( $opt{'c'} =~ m/(\[.*?[^\:]\])/g ) {
	    debug(3,"pattern ".@patterns."=$pattern\n");
	    push @patterns,$pattern;
	}
    }

    if($opt{'r'}) {
	foreach my $pattern (@ARGV) {
	    debug(3,"pattern ".@patterns."=$pattern\n");
	    push @patterns,$pattern;
	}
    }
    debug(1,"Have ".@patterns." patterns\n");
}

sub usage() {
    print STDERR <<"EOF";
usage: $0 [-hd] [-v level] [-i] [-n num] -w file [-p number] [-c pattern] [-r pattern-1 pattern-2 ... pattern-n] 

    -h            : this help message
    -d            : print debugging messages to stderr instead of stdout
    -v level      : verbose output level (1 is informational, 2 is all)
    -m            : HTML-like output
    -i            : print result phrases incrementally, instead of all at once
    -n num        : maximum number of words in phrase, or 0 for no limit
    -w file       : wordlist to use, or - for stdin
    -p number     : phonespell mode, uses 1 and 0 as wildcard (convenience)
    -c pattern    : a single regex-like pattern which consists only of 
                    character classes (convenience) 
    -r p1 p2...pn : a list of regex patterns that each match one component of a word

notes: you must have either -r or -c, but you cannot have both. 

example: $0 -v -d -n 2 -w /usr/share/dict/words -c "[t][r][o][l][l][e][y][c][a][r]"

EOF
exit;
}


sub debug {
    my $level = shift;
    my $msg = shift;
    my $noprefix = shift;
    if($verbose >= $level) {
	if($noprefix) {
	    print $debugfh $msg;
	} else {
	    print $debugfh "$0: ".$msg;
	}
    }
}

sub innerspace {
    my $w1 = shift;
    my $w2 = shift;
    if($w1 eq "") {
	return($w2);
    } elsif($w2 eq "") {
	return($w1);
    } else {
	return($w1.' '.$w2);
    }
}

sub get_phrases {
    my $wordsleft = shift;
    my $startphrase = shift;
    my $patternref = shift;
    my @patterns = @$patternref;
    my @phrases = ();
    
    #debug(3,"get_phrases w=$wordsleft with ".@patterns." patterns and ".@phrases." phrases.\n"); 
    
    # first add matches to the whole "word" (if any)
    my $patstr = join('',@patterns);
    foreach my $word (match_word($patstr)) {
	my $matchphrase = innerspace($startphrase,$word);	
	debug(3,"full match! ".$matchphrase."\n");
	if($printinc > 0) {
	    if($htmlout) {
		print "$matchphrase<br/>\n";
	    } else {
		print "$matchphrase\n";
	    }
	}
	push @phrases,$matchphrase;
    }
    # debug(3,"now have phrases @phrases\n");

    if(($wordsleft > 1) && (@patterns > 1)) {
	# ready to split and recurse
	for(my $split=$#patterns; $split>0; $split--) {
	    debug(3,"split=$split\n");
	    # get matches to the first subword
	    my $firstpat = join '',@patterns[0..($split-1)];
	    my @firstmatches = match_word($firstpat);
	    debug(3,"Have ".@firstmatches." matches to first part $firstpat\n");
#	    if(@firstmatches > 0) {
	    foreach my $match (@firstmatches) {
		my @nextpat = @patterns[$split..$#patterns];
		debug(3,"recursing for match $match with patterns @nextpat\n");
		push @phrases, get_phrases($wordsleft-1,innerspace($startphrase,$match),\@nextpat);
		# debug(3,"now have phrases @phrases\n");
	    }
#	    }
#	    push @phrases,get_phrases($wordsleft-1,);
	}
    }
# else {
    debug(3,"get_phrases: ($wordsleft) returning ".@phrases." phrases.\n");
    debug(1,"$wordsleft:$startphrase @patterns found ".@phrases." phrases for ".@patterns." patterns.\n");
    return(@phrases);
#    }
}

sub match_word {
    my $pattern = shift;
    if($matchcache{$pattern}) {
	my @matches = @{$matchcache{$pattern}};
	debug(3,"Cache hit for $pattern (@matches)\n");
	return @matches;
    } else {
	debug(3,"match_word: checking for matches to pattern /".$pattern."/\n");
	my @matchedwords = ();
	foreach my $word (@wordlist) {
	    if($word =~ m/^$pattern$/) {
		push @matchedwords,$word;
		debug(3,"$word matches\n");
	    }
	}
	debug(3,"match_word: have ".@matchedwords." matching words.\n");
	$matchcache{$pattern} = [ @matchedwords ];
	return @matchedwords;
    }
}


init();

my $mastercclass = "";
foreach my $pattern (@patterns) {
    my $pat = $pattern;
    $pat =~ s/[\[\]]//g;
    $mastercclass .= $pat;
}

# Load wordlist
if(!($opt{'w'} eq '-')) {
    debug(2,"Opening wordlist ".$opt{'w'}."\n");
    open WORDLIST,"$opt{'w'}" or die "Could not open wordlist $opt{'w'}\n";
    $wordlistfh = *WORDLIST;
} else {
    debug(2,"Using STDIN for wordlist.\n");
    $wordlistfh = *STDIN;
}
my $maxlength = @patterns;
debug(4,"finding words which match [$mastercclass]{1,$maxlength}");
foreach my $word (<$wordlistfh>) {
    chomp $word;
    $word =~ s/\r//g;

    # Limit wordlist to words equal to or less than the length of the pattern we are using
    # NOTE: this assumes patterns only match 1 character
    # Also limit the wordlist to words containing only characters in the full list of patterns (master character-class)
    # TODO: make this an option
    if($word =~ m/^[$mastercclass]{1,$maxlength}$/o) {
	# Remove anything that is not a word character
	# TODO: make this an option
	$word =~ s/[^\w]//g;
	$word =~ s/\_//g;

	# Lowercase the word
	# TODO: make this an option
	$word = lc($word);
	
	push @wordlist,$word;
	debug(4,"*",1);
    } else {
	debug(4,".",1);
    }
}
debug(4,"\n",1);
if(!$opt{'w'} eq '-') {
    close $wordlistfh;
}
debug(2,"Have ".@wordlist." words of length ".$maxlength." or less.\n");
# Sort and Remove duplicates
@wordlist = sort {$a cmp $b} @wordlist;
{
    my $prev = 'XXX3173238029384does_not_exist_ever_in_the_wordlist_23232323XX';
    @wordlist = grep($_ ne $prev && (($prev) = $_), @wordlist);
}
debug(1,"Using ".@wordlist." unique words.\n");


#foreach my $word (@wordlist) {
#    print "$word\n";
#}

# NOTE: this assumes patterns only match 1 character
my $maxwords = @patterns;
if($opt{'n'}) {
    $maxwords = $opt{'n'};
}
debug(1,"Using $maxwords as the word limit.\n");

my @phrases;
debug(1,"Getting phrases.\n");
@phrases = get_phrases($maxwords,"",\@patterns);

debug(1,"DONE!\n");
if(! $printinc > 0) {
    foreach my $phrase (@phrases) {
	if($htmlout) {
	    print "$phrase<br/>\n";
	} else {
	    print "$phrase\n";
	}
    }
}

#my @matchkeys = keys %matchcache;
#debug(3,"Have matchcache keys @matchkeys\n");

