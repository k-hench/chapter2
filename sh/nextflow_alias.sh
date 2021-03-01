alias nf_run_gatk="nextflow run genotyping.nf -with-dag docs/genotyping.dot -with-report ../../docs/genotyping.html -with-timeline ../../docs/genotyping_timeline.html -c ../../nextflow.config -resume"
alias nf_run_allbp="nextflow run genotyping_all_basepairs.nf -with-dag docs/genotyping_allBP.dot -with-report ../../docs/genotyping_allBP.html -with-timeline ../../docs/genotyping_allBP_timeline.html -c ../../nextflow.config -resume"
alias nf_run_basic="nextflow run analysis_fst_gxp.nf -with-dag ../../docs/analysis_basic.dot -with-report ../../docs/analysis_basic.html -with-timeline ../../docs/analysis_basic_timeline.html -c ./nextflow.config -resume"
alias nf_run_phylo="nextflow run analysis_fasttree_twisst.nf -with-dag ../../docs/analysis_phylo.dot -with-report ../../docs/analysis_phylo.html -with-timeline ../../docs/analysis_phylo_timeline.html -c ../../nextflow.config -resume"
alias nf_run_dxy="nextflow run analysis_dxy.nf -with-dag ../../docs/analysis_dxy.dot -with-report ../../docs/analysis_dxy.html -with-timeline ../../docs/analysis_dxy_timeline.html -c ../../nextflow.config -resume"
alias nf_run_recombination="nextflow run analysis_recombination.nf -with-dag ../../docs/analysis_recombination.dot -with-report ../../docs/analysis_recombination.html -with-timeline ../../docs/analysis_recombination_timeline.html -c ../../nextflow.config -resume"
alias nf_run_msmc="nextflow run analysis_msmc.nf -with-dag ../../docs/analysis_msmc.dot -with-report ../../docs/analysis_msmc.html -with-timeline ../../docs/analysis_msmc_timeline.html -c ../../nextflow.config -resume"
alias nf_run_poptree="nextflow run analysis_fst_poptree.nf -with-dag ../../docs/analysis_poptree.dot -with-report ../../docs/analysis_poptree.html -with-timeline ../../docs/analysis_poptree.html -c nextflow.config -resume"
alias nf_run_hybrid="nextflow run analysis_hybridization.nf -with-dag ../../docs/analysis_hybrid.dot -with-report ../../docs/analysis_hybrid.html -with-timeline ../../docs/analysis_hybrid.html -c nextflow.config -resume"
alias nf_run_admixture="nextflow run analysis_admixture.nf -with-dag ../../docs/analysis_admixture.dot -with-report ../../docs/analysis_admixture.html -with-timeline ../../docs/analysis_admixture.html -c nextflow.config -resume"
alias nf_run_sliding_phylo="nextflow run analysis_sliding_phylo.nf -with-dag ../../docs/analysis_sliding_phylo.dot -with-report ../../docs/analysis_sliding_phylo.html -with-timeline ../../docs/analysis_sliding_phylo.html -c nextflow.config -resume"
alias nf_run_aa="nextflow run analysis_allele_age.nf -with-dag ../../docs/analysis_allele_age.dot -with-report ../../docs/analysis_allele_age.html -with-timeline ../../docs/analysis_allele_age.html -c nextflow.config -resume"
alias nf_run_pca="nextflow run analysis_pca.nf -with-dag ../../docs/analysis_pca.dot -with-report ../../docs/analysis_pca.html -with-timeline ../../docs/analysis_pca.html -c nextflow.config -resume"
alias nf_run_revpomo="nextflow run analysis_revpomo.nf -with-dag ../../docs/analysis_revpomo.dot -with-report ../../docs/analysis_revpomo.html -with-timeline ../../docs/analysis_revpomo.html -c nextflow.config -resume"
alias nf_run_fstsig="nextflow run analysis_fst_sign.nf -with-dag ../../docs/analysis_fstsig.dot -with-report ../../docs/analysis_fstsig.html -with-timeline ../../docs/analysis_fstsig.html -c nextflow.config -resume"
