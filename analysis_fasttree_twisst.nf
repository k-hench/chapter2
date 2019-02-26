#!/usr/bin/env nextflow
/* create channel of linkage groups */
Channel
	.from( ('01'..'09') + ('10'..'19') + ('20'..'24') )
	.map{ "LG" + it }
	.into{ lg_twisst }

Channel
	.fromFilePairs("1_genotyping/4_phased/phased_mac2.vcf.{gz,gz.tbi}")
	.into{ vcf_locations;  vcf_geno }

Channel
	.from( "bel", "hon", "pan")
	.set{ locations_ch }

locations_ch
	.combine( vcf_locations )
	.set{ vcf_location_combo }

process subset_vcf_by_location {
	label "L_20g2h_subset_vcf"

	input:
	set val( loc ), vcfId, file( vcf ) from vcf_location_combo

	output:
	set val( loc ), file( "${loc}.vcf.gz" ), file( "${loc}.pop" ) into ( vcf_loc_twisst )

	script:
	"""
	vcfsamplenames ${vcf[0]} | \
		grep ${loc} | \
		grep -v tor | \
		grep -v tab > ${loc}.pop

	vcftools --gzvcf ${vcf[0]} \
		--keep ${loc}.pop \
		--mac 3 \
		--recode \
		--stdout | bgzip > ${loc}.vcf.gz
	"""
}


/* 1) fasttree section ============== */
process vcf2geno {
	label 'L_20g15h_vcf2geno'

	input:
	set vcfId, file( vcf ) from vcf_geno

	output:
	file( "output.geno.gz" ) into snp_geno_tree

	script:
	"""
	python \$SFTWR/genomics_general/VCF_processing/parseVCF.py \
		-i ${vcf[0]} | gzip > output.geno.gz
	"""
}

process fasttree_prep {
	label 'L_190g15h_fasttree_prep'

	input:
	file( geno ) from snp_geno_tree

	output:
	file( "all_samples.SNP.fa" ) into ( fasttree_prep_ch )

	script:
	"""
	python \$SFTWR/genomics_general/genoToSeq.py -g ${geno} \
		-s  all_samples.SNP.fa \
		-f fasta \
		--splitPhased
	"""
}

process fasttree_run {
	label 'L_300g99h_fasttree_run'
	publishDir "2_analysis/fasttree/", mode: 'copy'

	input:
	file( fa ) from fasttree_prep_ch

	output:
	file( " all_samples.SNP.tree" ) into ( fasttree_output )

	script:
	"""
	fasttree -nt ${fa} > all_samples.SNP.tree
	"""
}
/*--------- tree construction -----------*/
/*
process plot_tree {
	label '32g1h.fasttree_plot'
	publishDir "out/fasttree/", mode: 'symlink'

	input:
	file( tree ) from fasttree_output

	output:
	file( "*.pdf" ) into fasttree_plot

	script:
	"""
	Rscript --vanilla \$BASE_DIR/R/plot_tree.R ${tree} \$BASE_DIR/vcf_samples.txt
	"""
}
*/

vcf_loc_twisst
	.combine( lg_twisst )
	.set{ vcf_loc_lg_twisst }

/* 2) Twisst section ============== */
process vcf2geno_loc {
	label 'L_20g15h_vcf2geno'

	input:
	set val( loc ), file( vcf ), file( pop ), val( lg )  from vcf_loc_lg_twisst

	output:
	set val( loc ), val( lg ), file( "${loc}.${lg}.geno.gz" ), file( pop ) into snp_geno_twisst

	script:
	"""
	vcftools \
		--gzvcf ${vcf} \
		--chr ${lg} \
		--recode \
		--stdout |
		gzip > intermediate.vcf.gz

	python \$SFTWR/genomics_general/VCF_processing/parseVCF.py \
	  -i intermediate.vcf.gz | gzip > ${loc}.${lg}.geno.gz
	"""
}

Channel.from( 50 ).set{ twisst_window_types }

snp_geno_twisst.combine( twisst_window_types ).set{ twisst_input_ch }
/*
process twisst_prep {
  label 'L_G120g40h_prep_twisst'

  input:
  set val( loc ), val( lg ), file( geno ), file( pop ), val( twisst_w ) from twisst_input_ch.filter { it[0] != 'pan' }

	output:
	set val( loc ), val( lg ), file( geno ), file( pop ), val( twisst_w ), file( "*.trees.gz" ), file( "*.data.tsv" ) into twisst_prep_ch

  script:
   """
	module load intel17.0.4 intelmpi17.0.4

   mpirun \$NQSII_MPIOPTS -np 1 \
	python \$SFTWR/genomics_general/phylo/phyml_sliding_windows.py \
      -g ${geno} \
      --windType sites \
      -w ${twisst_w} \
      --prefix ${loc}.${lg}.w${twisst_w}.phyml_bionj \
      --model HKY85 \
      --optimise n \
		--threads 1
	 """
}
*/
/*
process twisst_run {
	label 'L_G120g40h_run_twisst'
	publishDir "2_analysis/twisst/", mode: 'copy'

	input:
	set val( loc ), val( lg ), file( geno ), file( pop ), val( twisst_w ), file( tree ), file( data ) from twisst_prep_ch

	output:
	set val( loc ), val( lg ), val( twisst_w ), file( "*.weights.tsv.gz" ), file( "*.data.tsv" ) into ( twisst_output )

	script:
	"""
	module load intel17.0.4 intelmpi17.0.4

	awk '{print \$1"\\t"\$1}' ${pop} | \
	sed 's/\\(...\\)\\(...\\)\$/\\t\\1\\t\\2/g' | \
	cut -f 1,3 | \
	awk '{print \$1"_A\\t"\$2"\\n"\$1"_B\\t"\$2}' > ${loc}.${lg}.twisst_pop.txt

	TWISST_POPS=\$( cut -f 2 ${loc}.${lg}.twisst_pop.txt | sort | uniq | paste -s -d',' | sed 's/,/ -g /g; s/^/-g /' )

	mpirun \$NQSII_MPIOPTS -np 1 \
	python \$SFTWR/twisst/twisst.py \
	  --method complete \
	  -t ${tree} \
	  -T 1 \
	  \$TWISST_POPS \
	  --groupsFile ${loc}.${lg}.twisst_pop.txt | \
	  gzip > ${loc}.${lg}.w${twisst_w}.phyml_bionj.weights.tsv.gz
	"""
}
*/