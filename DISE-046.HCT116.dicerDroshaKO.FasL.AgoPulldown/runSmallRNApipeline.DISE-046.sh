#!/bin/bash
#SBATCH -A b1042
#SBATCH -p genomics
#SBATCH -t 48:00:00
#SBATCH -m a
#SBATCH --mem=50000
#SBATCH --chdir=/projects/b1069/DISE-046.HCT116.dicerDroshaKO.FasL.AgoPulldown
#SBATCH -o "%x.o%j"
#SBATCH --job-name=DISE-046
#SBATCH --nodes=1
#SBATCH -n 24

pipeline=/projects/b1069//smallRNAscripts/
project=DISE-046
workdir=/projects/b1069/DISE-046.HCT116.dicerDroshaKO.FasL.AgoPulldown
fastq=/projects/b1069/DISE-046.HCT116.dicerDroshaKO.FasL.AgoPulldown/fastq
currentDate=$(date +%F)

module load python/anaconda
module load R/3.2.1
module load bedtools
module load blast/2.7.1

cd $workdir
mkdir $workdir/$project.fastq


# Barcode files for demultiplexing found.  /projects/b1069/DISE-046.HCT116.dicerDroshaKO.FasL.AgoPulldown/HCT116_pLenti_FasL_NP-N_S2_R1_001.barcodes.txt /projects/b1069/DISE-046.HCT116.dicerDroshaKO.FasL.AgoPulldown/HCT116_uninfected_controls-C_S1_R1_001.barcodes.txt

# Demultiplexing samples for sample group HCT116_pLenti_FasL_NP-N_S2_R1_001
perl /projects/p20742/tools/bin//trim_galore $fastq/HCT116_pLenti_FasL_NP-N_S2_R1_001.fastq.gz --length 12 --dont_gzip
perl $pipeline/splitFastQwithTable.pl HCT116_pLenti_FasL_NP-N_S2_R1_001_trimmed.fq HCT116_pLenti_FasL_NP-N_S2_R1_001.barcodes.txt 0
mv *.fastq $workdir/$project.fastq/
gzip $workdir/$project.fastq/*.fastq &

# Demultiplexing samples for sample group HCT116_uninfected_controls-C_S1_R1_001
perl /projects/p20742/tools/bin//trim_galore $fastq/HCT116_uninfected_controls-C_S1_R1_001.fastq.gz --length 12 --dont_gzip
perl $pipeline/splitFastQwithTable.pl HCT116_uninfected_controls-C_S1_R1_001_trimmed.fq HCT116_uninfected_controls-C_S1_R1_001.barcodes.txt 0
mv *.fastq $workdir/$project.fastq/
gzip $workdir/$project.fastq/*.fastq &
wait

mkdir $workdir/readBased
# Pull out the individual reads for read-based analyses.
for f in DISE-046.fastq/*.f*q.gz
do
	# Determine the sample name based on the fastq file name.
	file=$(basename $f)
	echo $file
	sample=${file%%.gz}
	sample=${sample%%_trimmed.fq}
	sample=${sample%%.fastq}

	# Print the sample name for the fastq file.
	echo $sample
	gunzip $f

	# Pull out just the read sequences, leaving quality scores behind.
	grep ^@ -A 1 $project.fastq/$sample.fastq | grep -e ^A -e ^T -e ^G -e ^C -e ^N > readBased/$sample.justReads.fastq

	# Combine duplicate reads and add read counts to each line.
	sort readBased/$sample.justReads.fastq | uniq -c | sort -nr > readBased/$sample.justReads.uniqCounts.txt
	gzip $project.fastq/$sample*q &
	gzip readBased/$sample.justReads.fastq &
done

cd $workdir/readBased

# Process UMI sequences to split out reads into two sets, UMId and notUMId.
for f in *.justReads.uniqCounts.txt
do
	# Extract the sample name from the file name.
	file=$(basename $f)
	echo $file
	sample=${file%%.justReads.uniqCounts.txt}
	echo $sample

	# Generate two files, and remove UMI sequences from reads.
	# notUMId: A six nucleotide Unique Molecular Identifier (UMI) is removed from each read, and the numbers of reads associated with each UMI are summed to generate the raw read count for a particular sample.  For the UMId files, the number of unique UMIs is counted, regardless of how frequently each UMI is seen.
	(perl $pipeline/processUMIs.pl $sample.justReads.uniqCounts.txt) >& $sample.justReads.uniqCounts.UMI.dist.error.log
done
# Make tables from the reads.
# Counts are tabulated for each read and sample and two files are generated.  normCounts has the counts normalized per million reads in the column (sample) sum.  rawCounts has raw un-normalized data.
perl $pipeline/combineCounts.pl justReads.uniqCounts.notUMId.txt > $project.allreads.notUMId.normCounts.table.txt & 
perl $pipeline/combineCountsNotNorm.pl justReads.uniqCounts.notUMId.txt > $project.allreads.notUMId.rawCounts.table.txt & 
wait
# Adapter reads are identified as containing the substring GTCCGACGATC followed by 3-5 random nucleotides and removed from analysis.
perl $pipeline/deleteAdapterReads.pl $project.allreads.notUMId.rawCounts.table.txt > $project.noAdapter.notUMId.rawCounts.table.txt
perl $pipeline/deleteAdapterReads.pl $project.allreads.notUMId.normCounts.table.txt > $project.noAdapter.notUMId.normCounts.table.txt
# Make a fasta formatted file from the reads in the normCounts table
awk ' $1 !~ "Read" {printf ">%s.%d\n%s\n",$1,$NF,$1}' $project.noAdapter.notUMId.normCounts.table.txt > $project.noAdapter.notUMId.fa
# Reads were blasted (blastn-short) against custom blast databases created from all processed miRNAs and from the most recent RNA world databases, using the sequences appropriate for the organism (human or mouse). 
# Blast reads against human miRNAs
blastn -task blastn-short -query $project.noAdapter.notUMId.fa -db /projects/b1069//usefulFiles/humanMiRNAs.nr -outfmt 7 -num_threads 24 > $project.noAdapter.notUMId.miRNAs.nr.human.blast.txt & 
# Blast reads against human RNA world.
blastn -task blastn-short -query $project.noAdapter.notUMId.fa -db /projects/b1069//usefulFiles/human_and_virus_vbrc_all_cali_annoDB_sep2015.proc -outfmt 7 -num_threads 24 > $project.noAdapter.notUMId.RNAworld.human.blast.txt &
wait

# After blast runs are complete, resume analysis.

# Analyze blast data.
# Filter blast results
# Processed miRNA hits were filtered for 100% identity, and a match length of at least 18 bp.
awk ' $3 == 100 && $8 > $7 && $10 > $9 && $4 >= 18 && $9 < 10 ' $project.noAdapter.notUMId.miRNAs.nr.human.blast.txt  > $project.noAdapter.notUMId.miRNAs.nr.blast.filtered.txt
# RNAworld hits were filtered for at least 95% identity, where the match is within the first 9 bp of the sequencing reads.
awk ' $3 >= 95 && $8 > $7 && $10 > $9 && $7 < 10'  $project.noAdapter.notUMId.RNAworld.human.blast.txt  > $project.noAdapter.notUMId.RNAworld.blast.filtered.txt
for c in normCounts rawCounts
do
	echo $c
	perl /projects/b1069//usefulFiles/addAllToxicities.pl /projects/b1069//usefulFiles/6mer\ Seed\ toxes\ new.txt $project.noAdapter.notUMId.$c.table.txt > $project.noAdapter.notUMId.$c.table.withTox.txt
	perl $pipeline/addBLASTresults.pl $project.noAdapter.notUMId.$c.table.withTox.txt $project.noAdapter.notUMId.miRNAs.nr.blast.filtered.txt > $project.noAdapter.notUMId.$c.table.withTox.withMiRNAblast.txt
	perl $pipeline/addBLASTresults.pl $project.noAdapter.notUMId.$c.table.withTox.withMiRNAblast.txt $project.noAdapter.notUMId.RNAworld.blast.filtered.txt > $project.noAdapter.notUMId.$c.table.withTox.withMiRNAandRNAworld.blast.txt
	perl $pipeline/truncateBLASTresults.pl $project.noAdapter.notUMId.$c.table.withTox.withMiRNAandRNAworld.blast.txt > $project.noAdapter.notUMId.$c.table.withTox.withMiRNAandRNAworld.blast.trunc.txt
done

# Pull out smaller subsets of these tables for Excel.
perl $pipeline/thresholdNormTotal.pl $project.noAdapter.notUMId.rawCounts.table.withTox.withMiRNAandRNAworld.blast.trunc.txt 20 > $project.noAdapter.notUMId.rawCounts.table.withTox.withMiRNAandRNAworld.blast.trunc.minSum20.txt
perl $pipeline/thresholdNormTotal.pl $project.noAdapter.notUMId.normCounts.table.withTox.withMiRNAandRNAworld.blast.trunc.txt 6 > $project.noAdapter.notUMId.normCounts.table.withTox.withMiRNAandRNAworld.blast.trunc.minSum6.txt

# Run EdgeR on the comparisons file to identify differentially abundant reads.
# (Note that assembly is not actually used here, because these are reads, not gene IDs)
perl -pe "s/.justReads.uniqCounts.notUMId.txt//g" $project.noAdapter.notUMId.rawCounts.table.txt | perl -pe "s/_R1_001//g" > $project.noAdapter.notUMId.rawCounts.relabeled.txt
Rscript $pipeline/runEdgeRrnaSeq.reads.R --countFile=$project.noAdapter.notUMId.rawCounts.relabeled.txt --numCores=24 --runMDS=1 --filterOff=0 --assembly=hg38.mp
Rscript $pipeline/runEdgeRrnaSeq.reads.R --countFile=$project.noAdapter.notUMId.rawCounts.relabeled.txt --numCores=24 --runMDS=0 --filterOff=0 --assembly=hg38.mp --comparisonFile=/projects/b1069/DISE-046.HCT116.dicerDroshaKO.FasL.AgoPulldown/DISE-046.comparisons.csv

# Annotate each EdgeR result file with toxicities and blast results.
for edgeR in *$project*txt.edgeR.txt
do
	echo $edgeR
	comp=${edgeR%%.noAdapter.notUMId.rawCounts.relabeled.txt.edgeR.txt}
	echo $comp
	perl -pe "s/\"//g" $edgeR > $comp.edgeR.txt
	perl /projects/b1069//usefulFiles/addAllToxicities.pl /projects/b1069//usefulFiles/6mer\ Seed\ toxes\ new.txt $comp.edgeR.txt > $comp.edgeR.withTox.txt
	perl $pipeline/addBLASTresults.pl $comp.edgeR.withTox.txt $project.noAdapter.notUMId.miRNAs.nr.blast.filtered.txt > $comp.edgeR.withTox.withMiRNAblast.txt
	perl $pipeline/addBLASTresults.pl $comp.edgeR.withTox.withMiRNAblast.txt $project.noAdapter.notUMId.RNAworld.blast.filtered.txt > $comp.edgeR.withTox.withMiRNAandRNAworld.blast.txt
	perl $pipeline/truncateBLASTresults.pl $comp.edgeR.withTox.withMiRNAandRNAworld.blast.txt > $comp.edgeR.withTox.withMiRNAandRNAworld.blast.trunc.txt
done
