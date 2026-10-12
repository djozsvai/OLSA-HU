#!/usr/bin/perl
use strict;
use warnings;
use utf8;

binmode(STDOUT, ":utf8");

# --- 1. Configuration & Target Phonemes ---
my %target_cons = (
    't'=>11.97, 'n'=>10.98, 'l'=>9.01, 'm'=>8.59, 'k'=>7.92, 'r'=>6.31, 's'=>5.26, 'gy'=>4.75,
    'z'=>4.56,  'h'=>4.54,  'd'=>3.69, 'g'=>3.68, 'v'=>3.56, 'sz'=>2.57, 'b'=>2.25, 'j'=>1.72,
    'p'=>1.25,  'f'=>1.15,  'ny'=>0.72,'cs'=>0.66,'c'=>0.30, 'zs'=>0.30, 'ty'=>0.02
);

my %target_vows = (
    'e'=>27.0, 'a'=>21.5, 'o'=>13.2, 'i'=>10.8, 'é'=>8.0, 'á'=>7.8, 'u'=>2.8, 
    'ó'=>2.0,  'ö'=>1.8,  'ő'=>1.7,  'í'=>1.2,  'ü'=>1.2, 'ú'=>0.8, 'ű'=>0.3
);

# --- Syllable Targets ---
my $target_syl_gen = 2.0;  # Target for most categories
# Average syllable count for Hungarian numbers 1-10 is ~1.4 (e.g., egy, két, há-rom)
my $target_syl_num = 1.4;  

my @categories = qw(names numbers adjectives objects verbs);
my $words_per_cat = 10;
my $iterations = 110000; 
my $penalty_weight = 45;

# Hungarian Vowels for Syllable Counting
my $vowel_regex = qr/[aeiouáéíóöőúüű]/i;
# Phoneme Regex (for distribution analysis)
my $phoneme_regex = qr/(gy|sz|ny|cs|zs|ty|t|n|l|m|k|r|s|z|h|d|g|v|b|j|p|f|c|e|a|o|i|é|á|u|ó|ö|ő|í|ü|ú|ű)/;

# --- 2. Load and Pre-process Words ---
my (%pool, %word_phonemes, %word_syllables);

foreach my $cat (@categories) {
    open my $fh, "<:encoding(UTF-8)", "$cat.txt" or die "Could not open $cat.txt";
    while (my $word = <$fh>) {
        chomp $word; $word = lc($word); next unless $word =~ /\S/;
        push @{$pool{$cat}}, $word;
        
        # Cache Phonemes
        my @list = ($word =~ /$phoneme_regex/g);
        $word_phonemes{$word} = \@list;
        
        # Cache Syllables (Count of vowels)
        my @vowels = ($word =~ /$vowel_regex/g);
        $word_syllables{$word} = scalar @vowels;
    }
    close $fh;
}

# --- 3. Optimization Loop ---
my %selection;
foreach my $cat (@categories) {
    my @shuffled = sort { rand() <=> rand() } @{$pool{$cat}};
    $selection{$cat} = [ @shuffled[0..$words_per_cat-1] ];
}

my $current_score = calculate_fitness(\%selection);

print "Optimizing for Phonemes and Syllables...\n";

for (my $i = 0; $i < $iterations; $i++) {
    my $cat_to_change = $categories[rand @categories];
    my $idx = int(rand($words_per_cat));
    my $new_word = ${$pool{$cat_to_change}}[rand @{$pool{$cat_to_change}}];
    
    next if grep { $_ eq $new_word } @{$selection{$cat_to_change}};

    my $old_word = $selection{$cat_to_change}[$idx];
    $selection{$cat_to_change}[$idx] = $new_word;
    
    my $new_score = calculate_fitness(\%selection);
    
    if ($new_score < $current_score) {
        $current_score = $new_score;
    } else {
        $selection{$cat_to_change}[$idx] = $old_word;
    }
}

# --- 4. Export & Stats ---
open my $out, ">:encoding(UTF-8)", "output.txt" or die $!;
foreach my $cat (@categories) {
    my $sum_syl = 0;
    $sum_syl += $word_syllables{$_} for @{$selection{$cat}};
    my $avg = $sum_syl / $words_per_cat;

    print $out "___ " . uc($cat) . " (Average Syllable Count: $avg) ___\n";
    print $out join("\n", sort @{$selection{$cat}}) . "\n\n";
}
close $out;

print "Final Error Score: $current_score. Results in output.txt\n";

# --- Fitness Function with Syllable Penalty ---
sub calculate_fitness {
    my ($sel) = @_;
    my (%counts, $total_c, $total_v, $syl_penalty) = ((), 0, 0, 0);

    foreach my $cat (keys %$sel) {
        my $cat_syl_sum = 0;
        foreach my $word (@{$sel->{$cat}}) {
            # Phonemes
            foreach my $p (@{$word_phonemes{$word}}) {
                $counts{$p}++;
                exists $target_cons{$p} ? $total_c++ : $total_v++;
            }
            $cat_syl_sum += $word_syllables{$word};
        }
        
        # Calculate deviation from syllable target for this category
        my $avg = $cat_syl_sum / $words_per_cat;
        my $target = ($cat eq 'numbers') ? $target_syl_num : $target_syl_gen;
        $syl_penalty += ($target - $avg)**2 * $penalty_weight;
    }

    my $phoneme_error = 0;
    foreach my $p (keys %target_cons) {
        my $perc = $total_c > 0 ? ($counts{$p} || 0) / $total_c * 100 : 0;
        $phoneme_error += ($target_cons{$p} - $perc)**2;
    }
    foreach my $p (keys %target_vows) {
        my $perc = $total_v > 0 ? ($counts{$p} || 0) / $total_v * 100 : 0;
        $phoneme_error += ($target_vows{$p} - $perc)**2;
    }

    return $phoneme_error + $syl_penalty;
}