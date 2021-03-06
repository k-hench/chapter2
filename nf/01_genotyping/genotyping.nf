#!/usr/bin/env nextflow
/* ===============================================================
   Disclaimer: This pipeline needs a lot of time & memory to run:
   All in all we used roughly 10 TB and ran for about 1 Month
	 (mainly due to limited bandwidth on the cluster durint the
	 "receive_tuple step)
	 ===============================================================
*/

// git 1.1
/* open the pipeline based on the metadata spread sheet that includes all
 information necessary to assign read groups to the sequencing data,
 split the spread sheet by row and feed it into a channel */
Channel
	.fromPath('../../metadata/file_info.txt')
	.splitCsv(header:true, sep:"\t")
	.map{ row -> [ id:row.id, label:row.label, file_fwd:row.file_fwd, file_rev:row.file_rev, flowcell_id_fwd:row.flowcell_id_fwd, lane_fwd:row.lane_fwd, company:row.company] }
	.set { samples_ch }

// git 1.2
/* for every sequencing file, convert into ubam format and assign read groups */
process split_samples {
	label 'L_20g2h_split_samples'

	input:
	val x from samples_ch

	output:
	set val( "${x.label}.${x.lane_fwd}" ), file( "${x.label}.${x.lane_fwd}.ubam.bam" ) into ubams_mark, ubams_merge

	script:
	"""
	echo -e "---------------------------------"
	echo -e "Label:\t\t${x.label}\nFwd:\t\t${x.file_fwd}\nRev:\t\t${x.file_rev}"
	echo -e "Flowcell:\t${x.flowcell_id_fwd}\nLane:\t\t${x.lane_fwd}"
	echo -e "Read group:\t${x.flowcell_id_fwd}.${x.lane_fwd}\nCompany:\t${x.company}"

	mkdir -p \$BASE_DIR/temp_files

	gatk --java-options "-Xmx20G" \
		FastqToSam \
		-SM=${x.label} \
		-F1=\$BASE_DIR/data/seqdata/${x.file_fwd} \
		-F2=\$BASE_DIR/data/seqdata/${x.file_rev} \
		-O=${x.label}.${x.lane_fwd}.ubam.bam \
		-RG=${x.label}.${x.lane_fwd} \
		-LB=${x.label}".lib1" \
		-PU=${x.flowcell_id_fwd}.${x.lane_fwd} \
		-PL=Illumina \
		-CN=${x.company} \
		--TMP_DIR=\$BASE_DIR/temp_files;
	"""
}

// git 1.3
/* for every ubam file, mark Illumina adapters */
process mark_adapters {
	label 'L_20g2h_mark_adapters'
	tag "${sample}"

	input:
	set val( sample ), file( input ) from ubams_mark

	output:
	set val( sample ), file( "*.adapter.bam") into adapter_bams
	file "*.adapter.metrics.txt" into adapter_metrics

	script:
	"""
	gatk --java-options "-Xmx18G" \
		MarkIlluminaAdapters \
		-I=${input} \
		-O=${sample}.adapter.bam \
		-M=${sample}.adapter.metrics.txt \
		-TMP_DIR=\$BASE_DIR/temp_files;
	"""
}

// git 1.4
adapter_bams
	.combine(ubams_merge, by:0)
	.set {merge_input}

// git 1.5
/* this step includes a 3 step pipeline:
*  - re-transformatikon into fq format
*  - mapping aginst the reference genome_file
*  - merging with the basuch ubams to include
		read group information */
process map_and_merge {
	label 'L_75g24h8t_map_and_merge'
	tag "${sample}"

	input:
	set val( sample ), file( adapter_bam_input ), file( ubam_input ) from merge_input

	output:
	set val( sample ), file( "*.mapped.bam" ) into mapped_bams

	script:
	"""
	set -o pipefail
	gatk --java-options "-Xmx68G" \
		SamToFastq \
		-I=${adapter_bam_input} \
		-FASTQ=/dev/stdout \
		-INTERLEAVE=true \
		-NON_PF=true \
		-TMP_DIR=\$BASE_DIR/temp_files | \
	bwa mem -M -t 8 -p \$BASE_DIR/ressources/HP_genome_unmasked_01.fa /dev/stdin |
	gatk --java-options "-Xmx68G" \
		MergeBamAlignment \
		--VALIDATION_STRINGENCY SILENT \
		--EXPECTED_ORIENTATIONS FR \
		--ATTRIBUTES_TO_RETAIN X0 \
		-ALIGNED_BAM=/dev/stdin \
		-UNMAPPED_BAM=${ubam_input} \
		-OUTPUT=${sample}.mapped.bam \
		--REFERENCE_SEQUENCE=\$BASE_DIR/ressources/HP_genome_unmasked_01.fa.gz \
		-PAIRED_RUN true \
		--SORT_ORDER "unsorted" \
		--IS_BISULFITE_SEQUENCE false \
		--ALIGNED_READS_ONLY false \
		--CLIP_ADAPTERS false \
		--MAX_RECORDS_IN_RAM 2000000 \
		--ADD_MATE_CIGAR true \
		--MAX_INSERTIONS_OR_DELETIONS -1 \
		--PRIMARY_ALIGNMENT_STRATEGY MostDistant \
		--UNMAPPED_READ_STRATEGY COPY_TO_TAG \
		--ALIGNER_PROPER_PAIR_FLAGS true \
		--UNMAP_CONTAMINANT_READS true \
		-TMP_DIR=\$BASE_DIR/temp_files
	"""
}

// git 1.6
/* for every mapped sample,sort and mark duplicates
* (intermediate step is required to create .bai file) */
process mark_duplicates {
	label 'L_32g30h_mark_duplicates'
	publishDir "../../1_genotyping/0_sorted_bams/", mode: 'symlink'
	tag "${sample}"

	input:
	set val( sample ), file( input ) from mapped_bams

	output:
	set val { sample  - ~/\.(\d+)/ }, val( sample ), file( "*.dedup.bam") into dedup_bams
	file "*.dedup.metrics.txt" into dedup_metrics

	script:
	"""
	set -o pipefail
	gatk --java-options "-Xmx30G" \
		SortSam \
		-I=${input} \
		-O=/dev/stdout \
		--SORT_ORDER="coordinate" \
		--CREATE_INDEX=false \
		--CREATE_MD5_FILE=false \
		-TMP_DIR=\$BASE_DIR/temp_files \
		| \
	gatk --java-options "-Xmx30G" \
		SetNmAndUqTags \
		--INPUT=/dev/stdin \
		--OUTPUT=intermediate.bam \
		--CREATE_INDEX=true \
		--CREATE_MD5_FILE=true \
		-TMP_DIR=\$BASE_DIR/temp_files \
		--REFERENCE_SEQUENCE=\$BASE_DIR/ressources/HP_genome_unmasked_01.fa.gz

	gatk --java-options "-Xmx30G" \
		MarkDuplicates \
		-I=intermediate.bam \
		-O=${sample}.dedup.bam \
		-M=${sample}.dedup.metrics.txt \
		-MAX_FILE_HANDLES=1000  \
		-TMP_DIR=\$BASE_DIR/temp_files

	rm intermediate*
	"""
}

// git 1.7
/* index al bam files */
process index_bam {
	label 'L_32g1h_index_bam'
	tag "${sample}"

	input:
	set val( sample ), val( sample_lane ), file( input ) from dedup_bams

	output:
	set val( sample ), val( sample_lane ), file( input ), file( "*.bai") into ( indexed_bams, pir_bams )

	script:
	"""
	gatk --java-options "-Xmx30G" \
		BuildBamIndex \
		-INPUT=${input}
	"""
}

// git 1.8
/* collect all bam files for each sample */
indexed_bams
	.groupTuple()
	.set {tubbled}

// git 1.9
/* create one *.g.vcf file per sample */
process receive_tuple {
	label 'L_36g47h_receive_tuple'
	publishDir "../../1_genotyping/1_gvcfs/", mode: 'symlink'
	tag "${sample}"

	input:
	set sample, sample_lane, bam, bai from tubbled

	output:
	file( "*.g.vcf.gz") into gvcfs
	file( "*.vcf.gz.tbi") into tbis

	script:
	"""
	INPUT=\$(echo ${bam}  | sed  's/\\[/-I /g; s/\\]//g; s/,/ -I/g')

	gatk --java-options "-Xmx35g" HaplotypeCaller  \
	  -R=\$BASE_DIR/ressources/HP_genome_unmasked_01.fa \
	  \$INPUT \
	  -O ${sample}.g.vcf.gz \
	  -ERC GVCF
	"""
}

// git 1.10
/* collect and combine all *.g.vcf files */
process gather_gvcfs {
	label 'L_O88g90h_gather_gvcfs'
	publishDir "../../1_genotyping/1_gvcfs/", mode: 'symlink'
	echo true

	input:
	file( gvcf ) from gvcfs.collect()
	file( tbi ) from tbis.collect()

	output:
	set file( "cohort.g.vcf.gz" ), file( "cohort.g.vcf.gz.tbi" ) into ( gcvf_snps, gvcf_acs, gvcf_indel )

	script:
	"""
	GVCF=\$(echo " ${gvcf}" | sed 's/ /-V /g; s/vcf.gz/vcf.gz /g')

	gatk --java-options "-Xmx85g" \
		CombineGVCFs \
		-R=\$BASE_DIR/ressources/HP_genome_unmasked_01.fa \
		\$GVCF \
		-O cohort.g.vcf.gz
	"""
}

// git 1.11
/* actual genotyping step (varinat sites only) */
process joint_genotype_snps {
	label 'L_O88g90h_joint_genotype'
	publishDir "../../1_genotyping/2_raw_vcfs/", mode: 'symlink'

	input:
	set file( vcf ), file( tbi ) from gcvf_snps

	output:
	set file( "raw_var_sites.vcf.gz" ), file( "raw_var_sites.vcf.gz.tbi" ) into ( raw_var_sites, raw_var_sites_to_metrics )

	script:
	"""
	gatk --java-options "-Xmx85g" \
		GenotypeGVCFs \
		-R=\$BASE_DIR/ressources/HP_genome_unmasked_01.fa \
		-V=${vcf} \
		-O=intermediate.vcf.gz

	gatk --java-options "-Xmx85G" \
		SelectVariants \
		-R=\$BASE_DIR/ressources/HP_genome_unmasked_01.fa \
		-V=intermediate.vcf.gz \
		--select-type-to-include=SNP \
		-O=raw_var_sites.vcf.gz

	rm intermediate.*
	"""
}

// git 1.12
/* generate a LG channel */
Channel
	.from( ('01'..'09') + ('10'..'19') + ('20'..'24') )
	.into{ LG_ids1; LG_ids2 }

// git 1.13
/* produce metrics table to determine filtering thresholds - ups forgot to extract SNPS first*/
process joint_genotype_metrics {
	label 'L_28g5h_genotype_metrics'
	publishDir "../../1_genotyping/2_raw_vcfs/", mode: 'move'

	input:
	set file( vcf ), file( tbi ) from raw_var_sites_to_metrics

	output:
	file( "${vcf}.table.txt" ) into raw_metrics

	script:
	"""
	gatk --java-options "-Xmx25G" \
		VariantsToTable \
		--variant=${vcf} \
		--output=${vcf}.table.txt \
		-F=CHROM -F=POS -F=MQ \
		-F=QD -F=FS -F=MQRankSum -F=ReadPosRankSum \
		--show-filtered
	"""
}

// git 1.14
/* filter snps basaed on locus annotations, missingness
   and type (bi-allelic only) */
process filterSNPs {
	label 'L_78g10h_filter_Snps'
	publishDir "../../1_genotyping/3_gatk_filtered/", mode: 'symlink'

	input:
	set file( vcf ), file( tbi ) from raw_var_sites

	output:
	set file( "filterd_bi-allelic.vcf.gz" ), file( "filterd_bi-allelic.vcf.gz.tbi" ) into filtered_snps

	script:
	"""
	gatk --java-options "-Xmx75G" \
		VariantFiltration \
		-R=\$BASE_DIR/ressources/HP_genome_unmasked_01.fa \
		-V ${vcf} \
		-O=intermediate.vcf.gz \
		--filter-expression "QD < 2.5" \
		--filter-name "filter_QD" \
		--filter-expression "FS > 25.0" \
		--filter-name "filter_FS" \
		--filter-expression "MQ < 52.0 || MQ > 65.0" \
		--filter-name "filter_MQ" \
		--filter-expression "MQRankSum < -0.2 || MQRankSum > 0.2" \
		--filter-name "filter_MQRankSum" \
		--filter-expression "ReadPosRankSum < -2.0 || ReadPosRankSum > 2.0 " \
		--filter-name "filter_ReadPosRankSum"

	gatk --java-options "-Xmx75G" \
		SelectVariants \
		-R=\$BASE_DIR/ressources/HP_genome_unmasked_01.fa \
		-V=intermediate.vcf.gz \
		-O=intermediate.filterd.vcf.gz \
		--exclude-filtered

	vcftools \
		--gzvcf intermediate.filterd.vcf.gz \
		--max-missing-count 17 \
		--max-alleles 2 \
		--stdout  \
		--recode | \
		bgzip > filterd_bi-allelic.vcf.gz

	tabix -p vcf filterd_bi-allelic.vcf.gz

	rm intermediate.*
	"""
}

// git 1.15
// extract phase informative reads from
// alignments and SNPs
process extractPirs {
	label 'L_78g10h_extract_pirs'

	input:
	val( lg ) from LG_ids2
	set val( sample ), val( sample_lane ), file( input ), file( index ) from pir_bams.collect()
	set file( vcf ), file( tbi ) from filtered_snps

	output:
	set val( lg ), file( "filterd_bi-allelic.LG${lg}.vcf.gz" ), file( "filterd_bi-allelic.LG${lg}.vcf.gz.tbi" ), file( "PIRsList-LG${lg}.txt" ) into pirs_lg

	script:
	"""
	LG="LG${lg}"
	awk -v OFS='\t' -v dir=\$PWD -v lg=\$LG '{print \$1,dir"/"\$2,lg}' \$BASE_DIR/metadata/bamlist_proto.txt > bamlist.txt

	vcftools \
		--gzvcf ${vcf} \
		--chr \$LG \
		--stdout \
		--recode | \
		bgzip > filterd_bi-allelic.LG${lg}.vcf.gz

	tabix -p vcf filterd_bi-allelic.LG${lg}.vcf.gz

	extractPIRs \
		--bam bamlist.txt \
		--vcf filterd_bi-allelic.LG${lg}.vcf.gz \
		--out PIRsList-LG${lg}.txt \
		--base-quality 20 \
		--read-quality 15
	"""
}

// git 1.16
// run the actual phasing
process run_shapeit {
	label 'L_75g24h8t_run_shapeit'

	input:
	set val( lg ), file( vcf ), file( tbi ), file( pirs ) from pirs_lg

	output:
	file( "phased-LG${lg}.vcf.gz" ) into phased_lgs

	script:
	"""
	LG="LG${lg}"

	shapeit \
		-assemble \
		--input-vcf ${vcf} \
		--input-pir ${pirs} \
		--thread 8 \
		-O phased-LG${lg}

	shapeit \
		-convert \
		--input-hap phased-LG${lg} \
		--output-vcf phased-LG${lg}.vcf

	bgzip phased-LG${lg}.vcf
	"""
}

// git 1.17
// merge the phased LGs back together.
// the resulting vcf file represents
// the 'SNPs only' data set
process merge_phased {
	label 'L_28g5h_merge_phased_vcf'
	publishDir "../../1_genotyping/4_phased/", mode: 'move'

	input:
	file( vcf ) from phased_lgs.collect()

	output:
	set file( "phased.vcf.gz" ), file( "phased.vcf.gz.tbi" ) into phased_vcf
	set file( "phased_mac2.vcf.gz" ), file( "phased_mac2.vcf.gz.tbi" ) into phased_mac2_vcf

	script:
	"""
	vcf-concat \
		phased-LG* | \
		grep -v ^\$ | \
		tee phased.vcf | \
		vcftools --vcf - --mac 2 --recode --stdout | \
		bgzip > phased_mac2.vcf.gz

	bgzip phased.vcf

	tabix -p vcf phased.vcf.gz
	tabix -p vcf phased_mac2.vcf.gz
	"""
}


/* ========================================= */
/* appendix: generate indel masks for msmc: */

// git 1.18
// reopen the gvcf file to also genotype indels
process joint_genotype_indel {
	label 'L_O88g90h_genotype_indel'
	publishDir "../../1_genotyping/2_raw_vcfs/", mode: 'copy'

	input:
	set file( vcf ), file( tbi ) from gvcf_indel

	output:
	set file( "raw_var_indel.vcf.gz" ), file( "raw_var_indel.vcf.gz.tbi" ) into ( raw_indel, raw_indel_to_metrics )

	script:
	"""
	gatk --java-options "-Xmx85g" \
		GenotypeGVCFs \
		-R=\$REF_GENOME \
		-V=${vcf} \
		-O=intermediate.vcf.gz

	gatk --java-options "-Xmx85G" \
		SelectVariants \
		-R=\$REF_GENOME \
		-V=intermediate.vcf.gz \
		--select-type-to-include=INDEL \
		-O=raw_var_indel.vcf.gz

	rm intermediate.*
	"""
}

// git 1.19
// export indel metrics for filtering
process indel_metrics {
	label 'L_28g5h_genotype_metrics'
	publishDir "../../1_genotyping/2_raw_vcfs/", mode: 'copy'

	input:
	set file( vcf ), file( tbi ) from raw_indel_to_metrics

	output:
	file( "${vcf}.table.txt" ) into raw_indel_metrics

	script:
	"""
	gatk --java-options "-Xmx25G" \
		VariantsToTable \
		--variant=${vcf} \
		--output=${vcf}.table.txt \
		-F=CHROM -F=POS -F=MQ \
		-F=QD -F=FS -F=MQRankSum -F=ReadPosRankSum \
		--show-filtered
	"""
}

// git 1.20
// hard filter indels and create mask
process filterIndels {
	label 'L_78g10h_filter_indels'
	publishDir "../../1_genotyping/3_gatk_filtered/", mode: 'copy'

	input:
	set file( vcf ), file( tbi ) from raw_indel

	output:
	set file( "filterd.indel.vcf.gz" ), file( "filterd.indel.vcf.gz.tbi" ) into filtered_indel
	file( "indel_mask.bed.gz" ) into indel_mask_ch

	/* FILTER THRESHOLDS NEED TO BE UPDATED */

	script:
	"""
	gatk --java-options "-Xmx75G" \
		VariantFiltration \
		-R=\$REF_GENOME \
		-V ${vcf} \
		-O=intermediate.vcf.gz \
		--filter-expression "QD < 2.5" \
		--filter-name "filter_QD" \
		--filter-expression "FS > 25.0" \
		--filter-name "filter_FS" \
		--filter-expression "MQ < 52.0 || MQ > 65.0" \
		--filter-name "filter_MQ" \
		--filter-expression "SOR > 3.0" \
		--filter-name "filter_SOR" \
		--filter-expression "InbreedingCoeff < -0.25" \
		--filter-name "filter_InbreedingCoeff" \
		--filter-expression "MQRankSum < -0.2 || MQRankSum > 0.2" \
		--filter-name "filter_MQRankSum" \
		--filter-expression "ReadPosRankSum < -2.0 || ReadPosRankSum > 2.0 " \
		--filter-name "filter_ReadPosRankSum"

	gatk --java-options "-Xmx75G" \
		SelectVariants \
		-R=\$REF_GENOME \
		-V=intermediate.vcf.gz \
		-O=filterd.indel.vcf.gz \
		--exclude-filtered

	zcat filterd.indel.vcf.gz | \
		awk '! /\\#/' | \
		awk '{if(length(\$4) > length(\$5)) print \$1"\\t"(\$2-6)"\\t"(\$2+length(\$4)+4);  else print \$1"\\t"(\$2-6)"\\t"(\$2+length(\$5)+4)}' | \
		gzip -c > indel_mask.bed.gz

	rm intermediate.*
	"""
}

// git 1.21
/* create channel of linkage groups */
Channel
	.from( ('01'..'09') + ('10'..'19') + ('20'..'24') )
	.map{ "LG" + it }
	.into{ lg_ch }

// git 1.22
// attach linkage groups to indel masks
lg_ch.combine( filtered_indel ).set{ filtered_indel_lg }

// git 1.23
// split indel mask by linkage group
process split_indel_mask {
	label 'L_loc_split_indel_mask'
	publishDir "../../ressources/indel_masks/", mode: 'copy'

	input:
	set val( lg ), file( bed ) from filtered_indel_lg

	output:
	set val( lg ), file( "indel_mask.${lg}.bed.gz " ) into lg_indel_mask

	script:
	"""
		gzip -cd ${bed} | \
		grep ${lg} | \
		gzip -c > indel_mask.${lg}.bed.gz
	"""
}
