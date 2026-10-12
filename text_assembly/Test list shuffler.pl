#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);   
use List::Util qw(shuffle);

# Matrix vocabulary derived from the table
my %word_table = (
    alany => [
        "Anna", "Béla", "Fanni", "Gyula", "Imre", 
        "József", "Márta", "Miklós", "Norbert", "Ádám"
    ],
    mennyisegjelzo => [
        "egy", "három", "húsz", "negyven", "négy", 
        "pár", "sok", "tíz", "öt", "kilenc"
    ],
    minosegjelzo => [
        "barna", "boldog", "egyenes", "egész", "hasznos", 
        "hideg", "kerek", "magas", "vizes", "élénk"
    ],
    targy => [
        "csizmát", "erdőt", "kaput", "kefét", "macskát", 
        "mezőt", "nyilat", "sarkot", "széket", "zoknit"
    ],
    allitmany => [
        "cipel", "emel", "gondol", "kerül", "mozgat", 
        "mutat", "olvas", "rajzol", "ágyaz", "vezet"
    ]
);

my @categories = ("alany", "mennyisegjelzo", "minosegjelzo", "targy", "allitmany");

sub generate_matrix_sentences {
    # Set seed with a meaning :)
    srand(42);
    
    # Each transition delta (0..9) must occur exactly 3 times across 30 lists
    my @base_deltas = map { ($_) x 3 } (0..9);
    
    my @d1 = shuffle(@base_deltas);
    my @d2 = shuffle(@base_deltas);
    my @d3 = shuffle(@base_deltas);
    my @d4 = shuffle(@base_deltas);
    
    my @sentences;
    
    # Generate 30 base lists
    for my $list_idx (0..29) {
        # Calculate column shift offsets for list_idx
        my $s0 = 0;
        my $s1 = $d1[$list_idx];
        my $s2 = ($s1 + $d2[$list_idx]) % 10;
        my $s3 = ($s2 + $d3[$list_idx]) % 10;
        my $s4 = ($s3 + $d4[$list_idx]) % 10;
        
        my @shifts = ($s0, $s1, $s2, $s3, $s4);
        
        # Generate 10 sentences for each list
        for my $sentence_idx (0..9) {
            my @words;
            for my $col_idx (0..$#categories) {
                my $category = $categories[$col_idx];
                my $word_idx = ($sentence_idx + $shifts[$col_idx]) % 10;
                push @words, $word_table{$category}->[$word_idx];
            }
            push @sentences, join(" ", @words);
        }
    }
    
    return @sentences;
}

sub save_sentences_to_file {
    my ($filename) = @_;
    $filename //= "Test list 300.txt";
    
    my @sentences = generate_matrix_sentences();
    
    open(my $fh, '>:encoding(UTF-8)', $filename) 
        or die "Could not open file '$filename' $!";
        
    for my $sentence (@sentences) {
        print $fh "$sentence\n";
    }
    
    close($fh);
    
    print "Successfully generated " . scalar(@sentences) . " sentences and saved to '$filename'.\n";
}

save_sentences_to_file();