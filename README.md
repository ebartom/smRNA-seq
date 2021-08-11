![SPOROS logo](https://github.com/ebartom/Sporos/blob/main/SPOROS2.jpg?raw=true)

MicroRNAs (or miRNAs) are 18-22 nucleotide long noncoding short (s)RNAs that play key roles in cellular biology, suppressing gene expression by targeting the 3' untranslated region of target mRNAs. miRNAs are typically studied by sequencing short RNAs from a biological sample and then aligning them to a reference genome.  However, since the core function of a miRNA is mediated by the seed sequence located in positions 2-7 of the miRNA guide strand, we wished to group miRNAs by their 6mer seed rather than by evolutionary history and miRNA family.  To this end, **we have created a read-based analysis pipeline for analyzing short RNA sequencing data, called SPOROS**.

We have previously shown that G-rich 6mer seed sequences can kill cells by targeting C-rich 6mer seed matches located in genes that are critical for cell survival. This results in induction of Death Induced by Survival gene Elimination (DISE), also referred to as 6mer Seed Toxicity. For much more detail on 6mer seed toxicity and DISE, we refer you to prior publications from our group.

* W. Putzbach, Q.Q. Gao, M. Patel, S. van Dongen, A. Haluck-Kangas, A.A. Sarshad, E. Bartom, K.Y. Kim, D.M. Scholtens, M. Hafner, J.C. Zhao, A.E. Murmann, M.E. Peter, [Many si/shRNAs can kill cancer cells by targeting multiple survival genes through an off-target mechanism](https://doi.org/10.7554/eLife.29702), _eLife_ 6 (2017) e29702.

* Q.Q. Gao, W. Putzbach, A.E. Murmann, S. Chen, G. Ambrosini, J.M. Peter, E. Bartom, M.E. Peter, [6mer seed toxicity in tumor suppressive miRNAs] (https://doi.org/10.1038/s41467-018-06526-1), _Nature Comm_ 9 (2018) 4504.

* M. Patel, E.T. Bartom, B. Paudel, M. Kocherginsky, K.L. O’’Shea, A.E. Murmann, M.E. Peter, Identification of the toxic 6mer seed consensus in human cancer cells, _BioRxiv_  (2020) <https://doi.org/10.1101/2020.12.22.424040>.

# Running SPOROS

SPOROS is a perl-based decision tree that takes a set of standardized inputs and prints out a shell script formatted for the SLURM scheduler.

A general outline of the pipeline can be seen here:
![SPOROS workflow](https://github.com/ebartom/Sporos/blob/main/SPOROS.flowChart.png?raw=true)
**Figure 1. SPOROS workflow developed to analyze seed toxicity of smRNA Seq data.** From left to right: smRNA seq data, either total or RISC-bound, are trimmed and cleaned and then compiled into a counts table. Rare reads are removed (fewer counts than the number of samples) and the remaining reads are BLASTed against all mature miRNAs or RNA World data sets of all small RNAs (either human or mouse). Reads that hit artificial sequences in the RNAworld datasets are again removed. The remaining raw counts table can be normalized to 1 million reads per sample or column or used for differential expression analysis. A raw counts table can also be an alternative input, instead of starting from reads.  RawCounts, NormCounts, or differential tables are annotated with 6 mer seed, 6 mer seed viability, miRNA, RNAworld to generate Output A tables.  At this point the miRNA content (%) can be determined. Reads of this Output A file are collapsed according to 6mer seed and RNA type resulting in Output B. At this point all short RNAs can be analyzed (sRNA) or just the miRNA fraction. Output B is fed into four scripts generating four output files: C: A Seed Tox graph that depicts all miRNAs as peaks according to their seed viability; D: Average seed toxicity of all reads in a samples depicted as box and whisker plot; E: Weblogo plot showing the average seed composition in positions 1-6 of the 6mer seed in each sample; F: The result of a multinomial mixed model odds ratio analysis allowing to compare both different 6mer seeds as well as differences in each position of different seeds. The hierarchy of folders and  subfolders generated by SPOROS is shown in a grey box.

We include analysis results from two examples to illustrate the power and utility of the pipeline. The first example is an in-house smRNA Seq dataset of RISC-bound sRNAs in a wild-type (wt) human cancer cell line and two mutant cell lines lacking expression of either Drosha or Dicer, resulting in a fundamental reduction in miRNA expression. The second example is based on a publicly available small RNA Seq data set derived from postmortem normal and Alzheimer's disease (AD) patient brains ([GSE63501](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE63501)).

## HCT116 cancer cells, with and without Dicer and Drosha

In the first example, reads were pulled down from the RISC complex as previously described ([Hauptmann et al](https://doi.org/10.1073/pnas.1506116112)).  The reads are sequenced in two large fastq files, which have to be demultiplexed with barcodes that are specific to each sample.  They also have six bp unique molecular identifiers (UMIs) which have to removed, four random nucleotides before the sequenced short RNA and two after.  The first step is to remove all of these extra sequences and also to eliminate any reads that are comprised of adapters.  After extracting the core RNAs, they are sorted, uniq'd, and counted using basic UNIX utilities.  The reads and counts from each sample are compiled into a single project-wide counts table.  Rare reads (with fewer raw read counts than the number of samples in the project) are removed.  We use BLAST to compare the remaining reads to two datasets of annotated RNAs, one of processed miRNAs, and one from RNAworld (<https://rnaworld.rockefeller.edu/>).  Significant homology to a sequence previously labeled as an adapter, marker, or other artificial sequence in RNAworld leads to a read's removal from the table.

Once a table has been generated with the remaining reads and their counts in every sample, the 6mer seed for each read is extracted from positions 2-7, and the predicted 6mer Seed Tox is looked up in a [toxicity table](https://raw.githubusercontent.com/ebartom/Sporos/main/usefulFiles/speciesToxes.txt). The predicted 6mer Seed Tox is the % viability determined by transfecting three human and three mouse cell lines with siRNAs carrying all of the 4096 possible 6mer seeds (see [Gao et al., 2018](https://www.nature.com/articles/s41467-018-06526-1), for more detail).  The read is also annotated with its top processed miRNA and RNAworld BLAST hits (if any).  

This is the end of the preliminary analysis, and now the core outputs of SPOROS begin.  To generate the code to run all of that preliminary analysis as well as the files listed below, we run the following command:

~~~
perl /projects/b1069/buildSPOROSpipeline.pl 
	-o human \
	-id Figure2 \
	-w /projects/b1069/Figure2.SPOROSpaper \
	-f /projects/b1069/Figure2.SPOROSpaper/input/fastq/ \
	-b /projects/b1069/Figure2.SPOROSpaper/input/HCT116_Drosha_Dicer_rep1.barcodes.txt,/projects/b1069/Figure2.SPOROSpaper/input/HCT116_Drosha_Dicer_rep2.barcodes.txt
~~~

This calls the perl program at the heart of SPOROS, [buildSPOROSpipeline.pl](https://github.com/ebartom/Sporos/blob/main/buildSPOROSpipeline.pl). It specifies that the samples are human (-o human), that the project ID is Figure2 (-id Figure2), what the working directory is (-w /projects/b1069/Figure2.SPOROSpaper), where the fastq files can be found (-f /projects/b1069/Figure2.SPOROSpaper/input/fastq/), and the mapping between barcodes and sample names for demultiplexing (-b /projects/b1069/Figure2.SPOROSpaper/input/[HCT116\_Drosha\_Dicer\_rep1.barcodes.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/input/HCT116_Drosha_Dicer_rep1.barcodes.txt),/projects/b1069/Figure2.SPOROSpaper/input/HCT116\_Drosha\_Dicer\_rep2.barcodes.txt). The barcodes files should have the same prefix as the fastq files they pair with.  If your fastq samples already have any accessory sequences removed and are already demultiplexed, there is no need to provide a barcode file.  SPOROS will assume that if there is no barcode file, these steps are not necessary. All fastq files in the fastq directory (either *.fastq.gz or *.fq.gz) will be analyzed.  The shell script will be printed to the working directory.  For this data set, you can see the resulting shell script in [runSPOROSpipeline.Figure2.sh](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/runSPOROSpipeline.Figure2.sh).  Submitting this shell script to our SLURM job scheduler will run SPOROS and generate the following directories and files. If you need help setting up SPOROS with your environment, please email <ebartom@northwestern.edu>.

- [totalCounts/](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/) - this directory name indicates that these are analyses based on the total counts, not the differential ones.
	- [A_rawCounts.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/A_rawCounts.Figure2.txt) - The raw counts for this project, annotated with 6mer seed, toxicity, and miRNA and RNAworld hits (if any)
	- [A_normCounts.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/A_normCounts.Figure2.txt) - The normalized counts for this project, annotated with 6mer seed, toxicity, and miRNA and RNAworld hits (if any). The normalization here is to a column sum  of 1 million for each sample, so these are essentially counts per million (CPM).
	- [B_collapsed.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/B_collapsed.Figure2.txt) - This file is derived from A_normCounts.Figure2.txt, but now any identical 6mers whose source reads have the same miRNA and RNAworld hits have been summed, and the source read removed.
	- [miRNA](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/miRNA/) - for this directory, only reads with a miRNA BLAST hit contribute to the analysis.  In doing our own analysis of this dataset, we used all short RNAs (not just miRNAs).  The miRNA analysis is still included here, and all the output formats are as described below for sRNA.
	- [sRNA](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/) - for this directory, all reads are included
		- [C_binned.sRNA.human.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/C_binned.sRNA.human.Figure2.txt) - in this file, toxicities are binned, and counts summed within each bins.  Each bin corresponds to a single toxicity / viability percentile, from 1 to 120.  These are manually plotted in Excel, and manually annotated with the most common source reads in a given toxicity range (referencing the B_collapsed output file).  See <https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/ToxicityPlot.Figure2.png> for an example of such a plot.
		- [Int_seedKeyed.sRNA.human.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/Int_seedKeyed.sRNA.human.Figure2.txt) - This is an intermediary file rather than an output file, but it is useful for deriving the later outputs.  This file is very similar to the output B_collapsed file, but in this file seeds are collapsed even if they have different miRNA and RNAworld BLAST hits.  All reference to reads and putative source RNAs are removed, and only seeds, toxicitys and counts are kept.
		- [D_toxAnalysis.DicerKO.avg.sRNA.human.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/D_toxAnalysis.DicerKO.avg.sRNA.human.Figure2.txt) - There is one D_toxAnalysis file for each original sample.  If the samples are labeled with a clear rep1, rep2 structure for each sample name, an average of the replicates will be made for each sample as well.  To generate these files, seeds with the same toxicity are summed, and the seed identity discarded.  Then the count corresponding to the toxicity is normalized, so that the total sum of all the counts is 1000, and each normalized count is rounded to the nearest integer.  Each toxicity is printed according to its integer count.  This is used to plot the distribution of toxicities for a given sample, with each toxicity listed the number of times that reads with seeds corresponding to that toxicity were seen in the original samples.  The boxplots can be generated manually, or SPOROS will make a basic boxplot to show the general trends.
		- [D_toxAnalysis.DicerKO.rep1.sRNA.human.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/D_toxAnalysis.DicerKO.rep1.sRNA.human.Figure2.txt)
		- [D_toxAnalysis.DicerKO.rep2.sRNA.human.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/D_toxAnalysis.DicerKO.rep2.sRNA.human.Figure2.txt)
		- [D_toxAnalysis.DroshaKO.avg.sRNA.human.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/D_toxAnalysis.DroshaKO.avg.sRNA.human.Figure2.txt)
		- [D_toxAnalysis.DroshaKO.rep1.sRNA.human.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/D_toxAnalysis.DroshaKO.rep1.sRNA.human.Figure2.txt)
		- [D_toxAnalysis.DroshaKO.rep2.sRNA.human.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/D_toxAnalysis.DroshaKO.rep2.sRNA.human.Figure2.txt)
		- [D_toxAnalysis.Wildtype.avg.sRNA.human.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/D_toxAnalysis.Wildtype.avg.sRNA.human.Figure2.txt)
		- [D_toxAnalysis.Wildtype.rep1.sRNA.human.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/D_toxAnalysis.Wildtype.rep1.sRNA.human.Figure2.txt)
		- [D_toxAnalysis.Wildtype.rep2.sRNA.human.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/D_toxAnalysis.Wildtype.rep2.sRNA.human.Figure2.txt)
		- [D_toxAnalysis.combined.sRNA.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/D_toxAnalysis.combined.sRNA.txt) - For plotting purposes, the toxicity files are compiled back into a single table.  If there are average files, those are used, otherwise each sample is added as an individual column in this table.
		- [D_toxAnalysis.combined.sRNA.txt.box.png](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/D_toxAnalysis.combined.sRNA.txt.box.png) - The resulting Box plot.
		- [E_seedAnalysis.DicerKO.avg.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.DicerKO.avg.sRNA.Figure2.txt) - The E\_seedAnalysis files are very similar to the D_toxAnalysis files, but instead of summing read counts corresponding to the same toxicity, read counts are summed if they correspond to the same 6mer seed.  Again, once all of the read counts are summed corresponding to each seed in each sample, the per sample counts are normalized to 1000, and then rounded to the nearest integer.  Each 6mer seed is then printed according to its integer count.  This is an input file for [Weblogo](http://weblogo.threeplusone.com/manual.html), which we run on the command line as part of SPOROS.
		- [E_seedAnalysis.DicerKO.avg.sRNA.Figure2.png](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.DicerKO.avg.sRNA.Figure2.png) - the Weblogo plot corresponding to the paired input file.
		- [E_seedAnalysis.DicerKO.rep1.sRNA.Figure2.png](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.DicerKO.rep1.sRNA.Figure2.png)
		- [E_seedAnalysis.DicerKO.rep1.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.DicerKO.rep1.sRNA.Figure2.txt)
		- [E_seedAnalysis.DicerKO.rep2.sRNA.Figure2.png](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.DicerKO.rep2.sRNA.Figure2.png)
		- [E_seedAnalysis.DicerKO.rep2.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.DicerKO.rep2.sRNA.Figure2.txt)
		- [E_seedAnalysis.DroshaKO.avg.sRNA.Figure2.png](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.DroshaKO.avg.sRNA.Figure2.png)
		- [E_seedAnalysis.DroshaKO.avg.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.DroshaKO.avg.sRNA.Figure2.txt)
		- [E_seedAnalysis.DroshaKO.rep1.sRNA.Figure2.png](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.DroshaKO.rep1.sRNA.Figure2.png)
		- [E_seedAnalysis.DroshaKO.rep1.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.DroshaKO.rep1.sRNA.Figure2.txt)
		- [E_seedAnalysis.DroshaKO.rep2.sRNA.Figure2.png](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.DroshaKO.rep2.sRNA.Figure2.png)
		- [E_seedAnalysis.DroshaKO.rep2.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.DroshaKO.rep2.sRNA.Figure2.txt)
		- [E_seedAnalysis.Wildtype.avg.sRNA.Figure2.png](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.Wildtype.avg.sRNA.Figure2.png)
		- [E_seedAnalysis.Wildtype.avg.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.Wildtype.avg.sRNA.Figure2.txt)
		- [E_seedAnalysis.Wildtype.rep1.sRNA.Figure2.png](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.Wildtype.rep1.sRNA.Figure2.png)
		- [E_seedAnalysis.Wildtype.rep1.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.Wildtype.rep1.sRNA.Figure2.txt)
		- [E_seedAnalysis.Wildtype.rep2.sRNA.Figure2.png](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.Wildtype.rep2.sRNA.Figure2.png)
		- [E_seedAnalysis.Wildtype.rep2.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/E_seedAnalysis.Wildtype.rep2.sRNA.Figure2.txt)
		- [F_seedExpand.DicerKO.avg.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/F_seedExpand.DicerKO.avg.sRNA.Figure2.txt) - the F\_seedExpand files are based on the same data as the E\_seedAnalysis files, but each position in each seed is further enumerated.  These files are used as input for the mixed model analysis.  The code for this analysis is included here, but it is customized for each project rather than generalized.  **Add links here**
		- [F_seedExpand.DicerKO.rep1.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/F_seedExpand.DicerKO.rep1.sRNA.Figure2.txt)
		- [F_seedExpand.DicerKO.rep2.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/F_seedExpand.DicerKO.rep2.sRNA.Figure2.txt)
		- [F_seedExpand.DroshaKO.avg.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/F_seedExpand.DroshaKO.avg.sRNA.Figure2.txt)
		- [F_seedExpand.DroshaKO.rep1.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/F_seedExpand.DroshaKO.rep1.sRNA.Figure2.txt)
		- [F_seedExpand.DroshaKO.rep2.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/F_seedExpand.DroshaKO.rep2.sRNA.Figure2.txt)
		- [F_seedExpand.Wildtype.avg.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/F_seedExpand.Wildtype.avg.sRNA.Figure2.txt)
		- [F_seedExpand.Wildtype.rep1.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/F_seedExpand.Wildtype.rep1.sRNA.Figure2.txt)
		- [F_seedExpand.Wildtype.rep2.sRNA.Figure2.txt](https://github.com/ebartom/Sporos/blob/main/Figure2.SPOROSpaper/totalCounts/sRNA/F_seedExpand.Wildtype.rep2.sRNA.Figure2.txt)
