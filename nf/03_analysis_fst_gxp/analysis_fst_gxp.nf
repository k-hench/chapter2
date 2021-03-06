#!/usr/bin/env nextflow
// git 3.1
// open genotype data
Channel
	.fromFilePairs("../../1_genotyping/4_phased/phased_mac2.vcf.{gz,gz.tbi}")
	.into{ vcf_locations; vcf_filter; vcf_gxp; vcf_adapt }

// git 3.2
// initialize location channel
Channel
	.from( "bel", "hon", "pan")
	.set{ locations_ch }

// git 3.3
// attach genotypes to location
locations_ch
	.combine( vcf_locations )
	.set{ vcf_location_combo }

// git 3.4
// define location specific sepcies set
Channel.from( [[1, "ind"], [2, "may"], [3, "nig"], [4, "pue"], [5, "uni"]] ).into{ bel_spec1_ch; bel_spec2_ch }
Channel.from( [[1, "abe"], [2, "gum"], [3, "nig"], [4, "pue"], [5, "ran"], [6, "uni"]] ).into{ hon_spec1_ch; hon_spec2_ch }
Channel.from( [[1, "nig"], [2, "pue"], [3, "uni"]] ).into{ pan_spec1_ch; pan_spec2_ch }

// git 3.5
// subset data to local hamlets
process subset_vcf_by_location {
	label "L_20g2h_subset_vcf"

	input:
	set val( loc ), vcfId, file( vcf ) from vcf_location_combo

	output:
	set val( loc ), file( "${loc}.vcf.gz" ), file( "${loc}.pop" ) into ( vcf_loc_pair1, vcf_loc_pair2, vcf_loc_pair3 )

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
		--stdout | gzip > ${loc}.vcf.gz
	"""
}

// git 3.6
// subset the global data set to hamlets only
process subset_vcf_hamlets_only {
	label "L_20g15h_filter_hamlets_only"
	publishDir "../../1_genotyping/4_phased/", mode: 'copy' , pattern: "*.vcf.gz"
	//module "R3.5.2"

	input:
	set vcfId, file( vcf ) from vcf_filter

	output:
	file( "hamlets_only.vcf.gz*" ) into vcf_hamlets_only
	set file( "hamlets_only.vcf.gz*" ), file( "hamlets_only.pop.txt" ) into vcf_multi_fst

	script:
	"""
	vcfsamplenames ${vcf[0]} | \
		grep -v "abe\\|gum\\|ind\\|may\\|nig\\|pue\\|ran\\|uni" > outgroup.pop

	vcfsamplenames ${vcf[0]} | \
		grep "abe\\|gum\\|ind\\|may\\|nig\\|pue\\|ran\\|uni" | \
		awk '{print \$1"\\t"\$1}' | \
		sed 's/\\t.*\\(...\\)\\(...\\)\$/\\t\\1\\t\\2/g' > hamlets_only.pop.txt

	vcftools \
		--gzvcf ${vcf[0]} \
		--remove outgroup.pop \
		--recode \
		--stdout | gzip > hamlets_only.vcf.gz
	"""
}

// ----------- Fst section -----------
// git 3.7
// compute global fst
process fst_multi {
	label 'L_20g15h_fst_multi'
	publishDir "../../2_analysis/fst/50k/", mode: 'copy' , pattern: "*.50k.tsv.gz"
	publishDir "../../2_analysis/fst/10k/", mode: 'copy' , pattern: "*.10k.tsv.gz"
	publishDir "../../2_analysis/fst/logs/", mode: 'copy' , pattern: "*.log"
	publishDir "../../2_analysis/summaries", mode: 'copy' , pattern: "fst_outliers_998.tsv"
	//conda "$HOME/miniconda2/envs/py3"
	//module "R3.5.2"

	input:
	set file( vcf ), file( pop ) from vcf_multi_fst

	output:
	file( "multi_fst*" ) into multi_fst_output
	file( "fst_outliers_998.tsv" )  into fst_outlier_output

	script:
	"""
	awk '{print \$1"\\t"\$2\$3}' ${pop} > pop.txt

	for k in abehon gumhon indbel maybel nigbel nighon nigpan puebel puehon puepan ranhon unibel unihon unipan; do
	grep \$k pop.txt | cut -f 1 > pop.\$k.txt
	done

	POP="--weir-fst-pop pop.abehon.txt \
	--weir-fst-pop pop.gumhon.txt \
	--weir-fst-pop pop.indbel.txt \
	--weir-fst-pop pop.maybel.txt \
	--weir-fst-pop pop.nigbel.txt \
	--weir-fst-pop pop.nighon.txt \
	--weir-fst-pop pop.nigpan.txt \
	--weir-fst-pop pop.puebel.txt \
	--weir-fst-pop pop.puehon.txt \
	--weir-fst-pop pop.puepan.txt \
	--weir-fst-pop pop.ranhon.txt \
	--weir-fst-pop pop.unibel.txt \
	--weir-fst-pop pop.unihon.txt \
	--weir-fst-pop pop.unipan.txt"

	# fst by SNP
	# ----------
	vcftools --gzvcf ${vcf} \
	 \$POP \
	--stdout  2> multi_fst_snp.log | \
	gzip > multi_fst.tsv.gz

	# fst 50kb window
	# ---------------
	vcftools --gzvcf ${vcf} \
	 \$POP \
	--fst-window-step 5000 \
	--fst-window-size 50000 \
	--stdout  2> multi_fst.50k.log | \
	gzip > multi_fst.50k.tsv.gz

	# fst 10kb window
	# ---------------
	vcftools --gzvcf ${vcf} \
	 \$POP \
	--fst-window-step 1000 \
	--fst-window-size 10000 \
	--stdout  2> multi_fst.10k.log | \
	gzip > multi_fst_snp.tsv.gz

	Rscript --vanilla \$BASE_DIR/R/table_fst_outliers.R multi_fst.50k.tsv.gz
	"""
}

// git 3.8
// prepare pairwise fsts
// ------------------------------
/* (create all possible species pairs depending on location
   and combine with genotype subset (for the respective location))*/
// ------------------------------
/* channel content after joinig:
  set [0:val(loc), 1:file(vcf), 2:file(pop), 3:val(spec1), 4:val(spec2)]*/
// ------------------------------
bel_pairs_ch = Channel.from( "bel" )
	.join( vcf_loc_pair1 )
	.combine(bel_spec1_ch)
	.combine(bel_spec2_ch)
	.filter{ it[3] < it[5] }
	.map{ it[0,1,2,4,6]}
hon_pairs_ch = Channel.from( "hon" )
	.join( vcf_loc_pair2 )
	.combine(hon_spec1_ch)
	.combine(hon_spec2_ch)
	.filter{ it[3] < it[5] }
	.map{ it[0,1,2,4,6]}
pan_pairs_ch = Channel.from( "pan" )
	.join( vcf_loc_pair3 )
	.combine(pan_spec1_ch)
	.combine(pan_spec2_ch)
	.filter{ it[3] < it[5] }
	.map{ it[0,1,2,4,6]}
bel_pairs_ch.concat( hon_pairs_ch, pan_pairs_ch  ).set { all_fst_pairs_ch }

// git 3.9
// compute pairwise fsts
process fst_run {
	label 'L_32g4h_fst_run'
	publishDir "../../2_analysis/fst/50k/", mode: 'copy' , pattern: "*.50k.windowed.weir.fst.gz"
	publishDir "../../2_analysis/fst/10k/", mode: 'copy' , pattern: "*.10k.windowed.weir.fst.gz"
	publishDir "../../2_analysis/fst/logs/", mode: 'copy' , pattern: "${loc}-${spec1}-${spec2}.log"

	input:
	set val( loc ), file( vcf ), file( pop ), val( spec1 ), val( spec2 ) from all_fst_pairs_ch

	output:
	set val( loc ), file( "*.50k.windowed.weir.fst.gz" ), file( "${loc}-${spec1}-${spec2}.log" ) into fst_50k
	file( "*.10k.windowed.weir.fst.gz" ) into fst_10k_output
	file( "${loc}-${spec1}-${spec2}.log" ) into fst_logs

	script:
	"""
	grep ${spec1} ${pop} > pop1.txt
	grep ${spec2} ${pop} > pop2.txt

	vcftools --gzvcf ${vcf} \
		--weir-fst-pop pop1.txt \
		--weir-fst-pop pop2.txt \
		--fst-window-step 5000 \
		--fst-window-size 50000 \
		--out ${loc}-${spec1}-${spec2}.50k 2> ${loc}-${spec1}-${spec2}.log

	vcftools --gzvcf ${vcf} \
		--weir-fst-pop pop1.txt \
		--weir-fst-pop pop2.txt \
		--fst-window-size 10000 \
		--fst-window-step 1000 \
		--out ${loc}-${spec1}-${spec2}.10k

	gzip *.windowed.weir.fst
	"""
}

// git 3.10
/* collect the VCFtools logs to crate a table with the
   genome wide fst values */
process fst_globals {
	label 'L_loc_fst_globals'
	publishDir "../../2_analysis/summaries", mode: 'copy' , pattern: "fst_globals.txt"
	//module "R3.5.2"

	input:
	file( log ) from fst_logs.collect()

	output:
	file( "fst_globals.txt" ) into fst_glob

	script:
	"""
	cat *.log | \
		grep -E 'Weir and Cockerham|--out' | \
		grep -A 3 50k | \
		sed '/^--/d; s/^.*--out //g; s/.50k//g; /^Output/d; s/Weir and Cockerham //g; s/ Fst estimate: /\t/g' | \
		paste - - - | \
		cut -f 1,3,5 | \

	sed 's/^\\(...\\)-/\\1\\t/g' > fst_globals.txt
	"""
}

// ----------- G x P section -----------

// git 3.11
// reformat genotypes (1)
process plink12 {
	label 'L_20g2h_plink12'

	input:
	set vcfId, file( vcf ) from vcf_gxp

	output:
	set file( "GxP_plink.map" ), file( "GxP_plink.ped" ) into plink_GxP

	script:
	"""
	vcfsamplenames ${vcf[0]} | \
		grep -v "tor\\|tab\\|flo" | \
		awk '{print \$1"\\t"\$1}' | \
		sed 's/\\t.*\\(...\\)\\(...\\)\$/\\t\\1\\t\\2/g' > pop.txt

	vcftools \
		--gzvcf ${vcf[0]} \
		--plink \
		--out GxP_plink

	plink \
		--file GxP_plink \
		--recode12 \
		--out hapmap
	"""
}

// git 3.12
// reformat genotypes (2)
process GxP_run {
	label 'L_20g2h_GxP_binary'

	input:
	set file( map ), file( ped ) from plink_GxP

	output:
	set file( "*.bed" ), file( "*.bim" ),file( "*.fam" ) into plink_binary

	script:
	"""
	# convert genotypes into binary format (bed/bim/fam)
	plink \
		--noweb \
		--file GxP_plink \
		--make-bed \
		--out GxP_plink_binary
	"""
}

// git 3.13
// import phenotypes
Channel
	.fromPath("../../metadata/phenotypes.sc")
	.set{ phenotypes_raw }

// git 3.14
// run PCA on phenotypes
process phenotye_pca {
	label "L_loc_phenotype_pca"
	publishDir "../../2_analysis/phenotype", mode: 'copy' , pattern: "*.txt"
	//module "R3.5.2"

	input:
	file( sc ) from phenotypes_raw

	output:
	file( "phenotypes.txt" ) into phenotype_file
	file( "phenotype_pca*.pdf" ) into  phenotype_pca

	script:
	"""
	Rscript --vanilla \$BASE_DIR/R/phenotypes_pca.R ${sc}
	"""
}

// git 3.15
// setup GxP traits
Channel
	.from("Bars", "Snout", "Peduncle")
	.set{ traits_ch }

// git 3.16
// bundle GxP input
traits_ch.combine( plink_binary ).combine( phenotype_file ).set{ trait_plink_combo }

// git 3.17
// actually run the GxP
process gemma_run {
 label 'L_32g4h_GxP_run'
 publishDir "../../2_analysis/GxP/bySNP/", mode: 'copy'
 //module "R3.5.2"

 input:
 set  val( pheno ), file( bed ), file( bim ), file( fam ), file( pheno_file ) from trait_plink_combo

 output:
 file("*.GxP.txt.gz") into gemma_results

 script:
	"""
	source \$BASE_DIR/sh/body.sh
	BASE_NAME=\$(echo  ${fam} | sed 's/.fam//g')

	mv ${fam} \$BASE_NAME-old.fam
	cp \${BASE_NAME}-old.fam ${fam}

	# 1) replace the phenotype values
	Rscript --vanilla \$BASE_DIR/R/assign_phenotypes.R ${fam} ${pheno_file} ${pheno}

	# 2) create relatedness matrix of samples using gemma
	gemma -bfile \$BASE_NAME -gk 1 -o ${pheno}

	# 3) fit linear model using gemma (-lm)
	gemma -bfile \$BASE_NAME -lm 4 -miss 0.1 -notsnp -o ${pheno}.lm

	# 4) fit linear mixed model using gemma (-lmm)
	gemma -bfile \$BASE_NAME -k output/${pheno}.cXX.txt -lmm 4 -o ${pheno}.lmm

	# 5) reformat output
	sed 's/\\trs\\t/\\tCHROM\\tPOS\\t/g; s/\\([0-2][0-9]\\):/\\1\\t/g' output/${pheno}.lm.assoc.txt | \
		cut -f 2,3,9-14 | body sort -k1,1 -k2,2n | gzip > ${pheno}.lm.GxP.txt.gz
	sed 's/\\trs\\t/\\tCHROM\\tPOS\\t/g; s/\\([0-2][0-9]\\):/\\1\\t/g' output/${pheno}.lmm.assoc.txt | \
		cut -f 2,3,8-10,13-15 | body sort -k1,1 -k2,2n | gzip > ${pheno}.lmm.GxP.txt.gz
	"""
}

// git 3.18
// setup smoothing levels
Channel
	.from([[50000, 5000], [10000, 1000]])
	.set{ gxp_smoothing_levels }

// git 3.19
// apply all smoothing levels
gemma_results.combine( gxp_smoothing_levels ).set{ gxp_smoothing_input }

// git 3.20
// actually run the smoothing
process gemma_smooth {
	label 'L_20g2h_GxP_smooth'
	publishDir "../../2_analysis/GxP/${win}", mode: 'copy'

	input:
	set file( lm ), file( lmm ), val( win ), val( step ) from gxp_smoothing_input

	output:
	set val( win ), file( "*.lm.*k.txt.gz" ) into gxp_lm_smoothing_output
	set val( win ), file( "*.lmm.*k.txt.gz" ) into gxp_lmm_smoothing_output

	script:
	"""
	\$BASE_DIR/sh/gxp_slider ${lm} ${win} ${step}
	\$BASE_DIR/sh/gxp_slider ${lmm} ${win} ${step}
	"""
}

// Fst within species ---------------------------------------------------------
// git 3.21
// define species set
Channel
	.from( "nig", "pue", "uni")
	.set{ species_ch }

// git 3.22
// define location set
Channel.from( [[1, "bel"], [2, "hon"], [3, "pan"]]).into{ locations_ch_1;locations_ch_2 }

// git 3.23
// create location pairs
locations_ch_1
	.combine(locations_ch_2)
	.filter{ it[0] < it[2] }
	.map{ it[1,3]}
	.combine( species_ch )
	.combine( vcf_adapt )
	.set{ vcf_location_combo_adapt }

// git 3.24
// compute pairwise fsts
process fst_run_adapt {
	label 'L_20g4h_fst_run_adapt'
	publishDir "../../2_analysis/fst/adapt/", mode: 'copy' , pattern: "*.log"

	input:
	set val( loc1 ), val( loc2 ), val( spec ), val(vcf_indx), file( vcf ) from vcf_location_combo_adapt

	output:
	file( "adapt_${spec}${loc1}-${spec}${loc2}.log" ) into fst_adapt_logs

	script:
	"""
	vcfsamplenames ${vcf[0]} | grep ${spec}${loc1} > pop1.txt
	vcfsamplenames ${vcf[0]} | grep ${spec}${loc2} > pop2.txt

	vcftools --gzvcf ${vcf[0]} \
		--weir-fst-pop pop1.txt \
		--weir-fst-pop pop2.txt \
		--out adapt_${spec}${loc1}-${spec}${loc2} 2> adapt_${spec}${loc1}-${spec}${loc2}.log
	"""
}
