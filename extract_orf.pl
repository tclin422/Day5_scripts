#!/usr/bin/perl -w
use strict;
use warnings;

#--------------------------------------------------------------------------
# extract_orf.pl
#--------------------------------------------------------------------------
#
#
# This program retrives ORFs from a fasta multiple sequence file using the data
# from the output file a script named "find_full-length_hits.pl".
# 
# USAGE: perl extract_orf.pl <query_file> <sequence_database_to_search> <output_file>
#
# All files must be in the same directory.
#    
#
# @joewinnz
# Dec 2015
#
#
#--------------------------------------------------------------------------



#--------------------------------------------------------------------------#
#                                                                          #
#                               MAIN                                       #
#                                                                          #
#--------------------------------------------------------------------------#

#
# codon table hash
#
my %DNAtoAA = ('GCT' => 'A', 'GCC' => 'A', 'GCA' => 'A', 'GCG' => 'A', 'TGT' => 'C',
	       'TGC' => 'C', 'GAT' => 'D', 'GAC' => 'D', 'GAA' => 'E', 'GAG' => 'E',
	       'TTT' => 'F', 'TTC' => 'F', 'GGT' => 'G', 'GGC' => 'G', 'GGA' => 'G',
	       'GGG' => 'G', 'CAT' => 'H', 'CAC' => 'H', 'ATT' => 'I', 'ATC' => 'I',
	       'ATA' => 'I', 'AAA' => 'K', 'AAG' => 'K', 'TTG' => 'L', 'TTA' => 'L',
	       'CTT' => 'L', 'CTC' => 'L', 'CTA' => 'L', 'CTG' => 'L', 'ATG' => 'M',
	       'AAT' => 'N', 'AAC' => 'N', 'CCT' => 'P', 'CCC' => 'P', 'CCA' => 'P',
	       'CCG' => 'P', 'CAA' => 'Q', 'CAG' => 'Q', 'CGT' => 'R', 'CGC' => 'R',
	       'CGA' => 'R', 'CGG' => 'R', 'AGA' => 'R', 'AGG' => 'R', 'TCT' => 'S',
	       'TCC' => 'S', 'TCA' => 'S', 'TCG' => 'S', 'AGT' => 'S', 'AGC' => 'S',
	       'ACT' => 'T', 'ACC' => 'T', 'ACA' => 'T', 'ACG' => 'T', 'GTT' => 'V',
	       'GTC' => 'V', 'GTA' => 'V', 'GTG' => 'V', 'TGG' => 'W', 'TAT' => 'Y',
	       'TAC' => 'Y', 'TAA' => '*', 'TAG' => '*', 'TGA' => '*',
	       'ACN' => 'T', 'CCN' => 'P', 'CGN' => 'R', 'CTN' => 'L',
		   'GCN' => 'A', 'GGN' => 'G', 'GTN' => 'V', 'TCN' => 'S');

my $usage = "USAGE: perl extract_orf.pl \<query_file\> \<sequence_database_to_search\> \<output_file\>";

my ($list_file, $fasta_db, $out_file) = @ARGV;
unless ($list_file && $fasta_db && $out_file) {die "$usage\nAll files must be supplied\n"}

unless (-e $list_file) {die "Can't open $list_file: $!"}
unless (-e $fasta_db) {die "Can't open $fasta_db: $!"}

# Reads in each line from the data generated by a script called "find_full-length_hits.pl"
my @lines = ();
open (IN, $list_file) || die "Can't open $list_file: $!";
my $query;
while (<IN>) {
    chomp;
    next if (/^\s*$/);
    push (@lines, $_);
}
close IN;

# Reads in the contents of the fasta file line by line.
# Each header line is searched for the names in the list to retrieve.
# If found, the sequence following the header line is collected
# in a hash and the name of the sequence is removed from the list
# which has been stored in the array.
#

my $header = "";
my $seq = "";
my %sequences = ();
my $unique_ID = 0;
my $inSequence = 0;


# Reads in the fasta sequence database file into a hash
open (FASTA, "$fasta_db") || die "Can't open $fasta_db: $!";
while (<FASTA>) {
    chomp;
    if (/^>/) {
        if ($inSequence) {
	    # stops collecting the sequence lines and store
	    # the sequence in a hash with the unique ID in its header line
	    # as its key.
	    	if ($header =~ / /) {
	    		($unique_ID) = $header =~ /^>(\S+)\s.*$/;
	    	} else {
	    		$unique_ID = $header;
	    	}
	    	$seq = $header."\n".$seq."\n";
	    	$sequences{$unique_ID} = $seq;
	        $seq = "";
	      	$unique_ID = 0;
	        $inSequence = 0;
		} 
		if (!$inSequence) {
			$header = $_;
			$inSequence = 1;
		}
	} else {
    # collects the lines following the matching header line.
        $seq .= $_;
    }
}

# capture the last sequence entry...
($unique_ID) = split (" ", $header);
$seq = $header."\n".$seq."\n";
$sequences{$unique_ID} = $seq;
close FASTA;

my $tab_file = "";
if ($out_file =~ /^(\S+)\.\S+$/) {
	$tab_file = $1."\.tab";
} else {
	$tab_file = $out_file."\.tab";
}
my $found_seq_count = 0;
my $query_count = 0;
my @notFound = ();
open (OUT, ">$out_file") || die "Can't create output file $out_file: $!\n";
open (TAB_OUT, ">$tab_file") || die "Can't create output file $tab_file: $!\n";
$header = "";
$seq = "";
my $stopcodon_count = 0;
print TAB_OUT "Hit ID\tORF length\tSTOP codon\?\tHit to Query\tSequence\n";
foreach my $line(@lines) {
	next if ($line =~ /^Query/);  #skips the header line
	#skips the lines without any tabs
	if (!($line =~ /\t/)) {
		$line =~ s/>//;
		next;
	}
	my $isReversed = 0;
	my @columns = split /\t/, $line;
	# Extracts necessary info from data file created by the script "find_full-length_hits.pl"
	my $query_name = $columns[0];
	my $query_length = $columns[1];
	my $id_line = $columns[5];
	my $start = $columns[6];
	my $end = $columns[8];
	# Deals with the ORFs in reverse string
	if ($end < $start) {
		my $temp = $start;
		$start = $end;
		$end = $temp;
		$isReversed = 1;
	}			
	my ($id) = $id_line =~ /^(\S+)\s?/;
	unless ($id) {
		print "No id\!\n";
		exit;
	}
	$query_count++;
	if (exists ($sequences{$id})) {
		print "Found: $id\n";
		my $this_sequence = $sequences{$id};
		($header, $seq) = split /\n/, $this_sequence;
		my $start_coord = $start-1;
		my $extracted_seq = "";
		if ($isReversed) {
			$extracted_seq = reverse_com(substr ($seq, 0, $end));
		} else {
			$extracted_seq = substr ($seq, $start_coord);
		}
		my $stop_codon = "NO";
		($extracted_seq, $stop_codon) = find_orf($extracted_seq);
		my $orf_length = length($extracted_seq);
		my $pep_length = int($orf_length/3);
		if ($stop_codon eq "YES") {
			$id_line .= " contains STOP codon";
			$stopcodon_count++;
			$pep_length--;
		} else {
			$id_line .= "does not contain STOP codon";
		}
		my $coverage = sprintf("%.1f", ($pep_length/$query_length)*100);
		$id_line .= ", coverage=$coverage\%, Hit to query=$query_name";
		print OUT "\>$id_line\n";
		print OUT "$extracted_seq\n";
		print TAB_OUT "$id_line\t$orf_length\t$stop_codon\t$query_name\t$extracted_seq\n";
		$found_seq_count++;
	} else {
		$line .= "\n";
		push (@notFound, $line);
	}
}	
close OUT;
close TAB_OUT;

print "\nNumber of queries: $query_count\n";
print "Total sequences found: $found_seq_count\n";
print "Number of sequences with both START and STOP codons: $stopcodon_count\n";
if (@notFound) {
	print "Can't find...\n";
	print @notFound;
}

exit;



#--------------------------------------------------------------------------#
#                                                                          #
#                              SUBS                                        #
#                                                                          #
#--------------------------------------------------------------------------#


sub reverse_com {
	my ($inputSeq) = shift;
	$inputSeq =~ tr/ATGCatgc/TACGtacg/;
	reverse ($inputSeq);
}

#--------------------------------------------------------------------------

sub find_orf {
	my $sequence = shift;
	$sequence =~ tr/[a-z]/[A-Z]/;
	my $orf;
	my $with_stop_codon = "NO";
	my $start_codon = substr ($sequence, 0, 3);
	unless ($start_codon eq "ATG") {
		print "The sequence does not start with ATG\n";
		exit;
	}
	for (my $y = 0; $y < (length($sequence) - 3); $y += 3) {
		if (!defined $DNAtoAA{substr($sequence, $y, 3)}) {
			last;
		} else {
			$orf .= substr($sequence, $y, 3);
			if ($DNAtoAA{substr($sequence, $y, 3)} eq "\*") {
				$with_stop_codon = "YES";
				last;
			}
		}
	}
	return ($orf, $with_stop_codon);
}

#--------------------------------------------------------------------------