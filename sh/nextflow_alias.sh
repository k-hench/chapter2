alias nf_run_gatk="nextflow run genotyping.nf -with-dag docs/genotyping.dot -with-report ../../docs/genotyping.html -with-timeline ../../docs/genotyping_timeline.html -c ../../nextflow.config -resume"
alias nf_run_basic="nextflow run analysis_pca_admx_fst_gxp.nf -with-dag ../../docs/analysis_basic.dot -with-report ../../docs/analysis_basic.html -with-timeline ../../docs/analysis_basic_timeline.html -c ../../nextflow.config -resume"
alias nf_run_phylo="nextflow run analysis_fasttree_twisst.nf -with-dag ../../docs/analysis_phylo.dot -with-report ../../docs/analysis_phylo.html -with-timeline ../../docs/analysis_phylo_timeline.html -c ../../nextflow.config -resume"
alias nf_run_msmc="nextflow run analysis_msmc.nf -with-dag ../../docs/analysis_msmc.dot -with-report ../../docs/analysis_msmc.html -with-timeline ../../docs/analysis_msmc_timeline.html -c ../../nextflow.config -resume"