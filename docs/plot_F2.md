---
output: html_document
editor_options:
  chunk_output_type: console
---
# Figure 2



## Summary

This is the accessory documentation of Figure 2.
The Figure can be recreated by running the **R** script `plot_F2.R`:
```sh
cd $BASE_DIR

Rscript --vanilla R/fig/plot_F2.R 2_analysis/dxy/50k/ \
   2_analysis/fst/50k/multi_fst.50k.tsv.gz 2_analysis/GxP/50000/ \
   2_analysis/summaries/fst_outliers_998.tsv \
   https://raw.githubusercontent.com/simonhmartin/twisst/master/plot_twisst.R \
   2_analysis/twisst/weights/ ressources/plugin/trees/ \
   2_analysis/fasteprr/step4/fasteprr.all.rho.txt.gz \
   2_analysis/summaries/fst_globals.txt

```

## Details of `plot_F2.R`

In the following, the individual steps of the R script are documented.
It is an executable R script that depends on the accessory R package **GenomicOriginsScripts**.

### Config

The scripts start with a header that contains copy & paste templates to execute or debug the script:


```r
#!/usr/bin/env Rscript
# run from terminal:
# Rscript --vanilla R/fig/plot_F2.R 2_analysis/dxy/50k/ \
#    2_analysis/fst/50k/multi_fst.50k.tsv.gz 2_analysis/GxP/50000/ \
#    2_analysis/summaries/fst_outliers_998.tsv \
#    https://raw.githubusercontent.com/simonhmartin/twisst/master/plot_twisst.R \
#    2_analysis/twisst/weights/ ressources/plugin/trees/ \
#    2_analysis/fasteprr/step4/fasteprr.all.rho.txt.gz \
#    2_analysis/summaries/fst_globals.txt
# ===============================================================
# This script produces Figure 2 of the study "The genomic origins of a marine radiation"
# by Hench, McMillan an Puebla
# ---------------------------------------------------------------
# ===============================================================
# args <- c('2_analysis/dxy/50k/','2_analysis/fst/50k/multi_fst.50k.tsv.gz',
# '2_analysis/GxP/50000/', '2_analysis/summaries/fst_outliers_998.tsv',
# 'https://raw.githubusercontent.com/simonhmartin/twisst/master/plot_twisst.R',
# '2_analysis/twisst/weights/', 'ressources/plugin/trees/',
# '2_analysis/fasteprr/step4/fasteprr.all.rho.txt.gz', '2_analysis/summaries/fst_globals.txt')
```

The next section processes the input from the command line.
It stores the arguments in the vector `args`.
The R package **GenomicOriginsScripts** is loaded and the script name and the current working directory are stored inside variables (`script_name`, `plot_comment`).
This information will later be written into the meta data of the figure to help us tracing back the scripts that created the figures in the future.

Then we drop all the imported information besides the arguments following the script name and print the information to the terminal.


```r
args = commandArgs(trailingOnly=FALSE)
# setup -----------------------
library(GenomicOriginsScripts)
library(hypoimg)

cat('\n')
script_name <- args[5] %>% 
  str_remove(.,'--file=')

plot_comment <- script_name %>% 
  str_c('mother-script = ',getwd(),'/',.) 

args <- process_input(script_name, args)
```

```r
#> ── Script: scripts/plot_F2.R ────────────────────────────────────────────
#> Parameters read:
#>  ★ 1: 2_analysis/dxy/50k/
#>  ★ 2: 2_analysis/fst/50k/multi_fst.50k.tsv.gz
#>  ★ 3: 2_analysis/GxP/50000/
#>  ★ 4: 2_analysis/summaries/fst_outliers_998.tsv
#>  ★ 5: https://raw.githubusercontent.com/simonhmartin/twisst/master/plot_twisst.R
#>  ★ 6: 2_analysis/twisst/weights/
#>  ★ 7: ressources/plugin/trees/
#>  ★ 8: 2_analysis/fasteprr/step4/fasteprr.all.rho.txt.gz
#>  ★ 9: 2_analysis/summaries/fst_globals.txt
#> ─────────────────────────────────────────── /current/working/directory ──
```

The directories for the different data types are received and stored in respective variables.
Also, we source an external r script from the [original twisst github repository](https://github.com/simonhmartin/twisst) that we need to import the twisst data:


```r
# config -----------------------
dxy_dir <- as.character(args[1])
fst_file <- as.character(args[2])
gxp_dir <- as.character(args[3])
outlier_table <- as.character(args[4])
twisst_script <- as.character(args[5])
w_path <- as.character(args[6])
d_path <- as.character(args[7])
recombination_file <- as.character(args[8])
global_fst_file <- as.character(args[9])
source(twisst_script)
```

### Data import

Figure 2 contains wuite a lot of different data sets.
The main part of this script is just importing and organizing all of this data:
In the following we'll go step by step through the import of:

- differentiation data ($F_{ST}$)
- divergence data ($d_{XY}$, also containing diversity data - $\pi$)
- genotype $\times$ phenotype association data ($p_{Wald}$)
- recombination data ($\rho$)
- topology weighting data

We start with the import of the $F_{ST}$ data, specifically the data set containing the genome wide $F_{ST}$ computed for all populations simultaneously (joint $F_{ST}$).

The data file is read, the columns are renamed and the genomic position is added.
Then, only the genomic position and the $F_{ST}$ columns are selected and a window column is added for facetting in `ggplot()`.


```r
# start script -------------------
# import fst data
fst_data <- vroom::vroom(fst_file,delim = '\t') %>%
  select(CHROM, BIN_START, BIN_END, N_VARIANTS, WEIGHTED_FST) %>%
  setNames(., nm = c('CHROM','BIN_START', 'BIN_END', 'n_snps', 'fst') ) %>%
  add_gpos() %>%
  select(GPOS, fst) %>%
  setNames(., nm = c('GPOS','value')) %>%
  mutate(window = str_c('bold(',project_case('a'),'):joint~italic(F[ST])'))
```

```
## Rows: 111,943
## Cols: 6
## chr [1]: CHROM
## dbl [5]: BIN_START, BIN_END, N_VARIANTS, WEIGHTED_FST, MEAN_FST
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
```

Next, we import the $d_{XY}$ data.
Here we are importing all 28 pairwise comparisons, so we first collect all the file paths and the iterate the data import over all files.


```r
# import dxy data
dxy_files <- dir(dxy_dir)

dxy_data <- str_c(dxy_dir,dxy_files) %>%
  purrr::map(get_dxy) %>%
  bind_rows() %>%
  select(N_SITES:GPOS, run) %>%
  mutate(pop1 = str_sub(run,1,6),
         pop2 = str_sub(run,8,13))
```

```
## Rows: 111,728
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_abehon, pi_gumhon, dxy_abehon_gumhon, Fst_abeho...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,728
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_abehon, pi_nighon, dxy_abehon_nighon, Fst_abeho...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 110,100
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_abehon, pi_puehon, dxy_abehon_puehon, Fst_abeho...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 110,089
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_abehon, pi_ranhon, dxy_abehon_ranhon, Fst_abeho...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,728
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_abehon, pi_unihon, dxy_abehon_unihon, Fst_abeho...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,728
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_gumhon, pi_nighon, dxy_gumhon_nighon, Fst_gumho...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,728
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_gumhon, pi_puehon, dxy_gumhon_puehon, Fst_gumho...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,728
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_gumhon, pi_ranhon, dxy_gumhon_ranhon, Fst_gumho...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 109,930
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_gumhon, pi_unihon, dxy_gumhon_unihon, Fst_gumho...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,728
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_indbel, pi_maybel, dxy_indbel_maybel, Fst_indbe...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,195
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_indbel, pi_nigbel, dxy_indbel_nigbel, Fst_indbe...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,728
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_indbel, pi_puebel, dxy_indbel_puebel, Fst_indbe...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,728
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_indbel, pi_unibel, dxy_indbel_unibel, Fst_indbe...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,728
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_maybel, pi_nigbel, dxy_maybel_nigbel, Fst_maybe...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,728
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_maybel, pi_puebel, dxy_maybel_puebel, Fst_maybe...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,728
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_maybel, pi_unibel, dxy_maybel_unibel, Fst_maybe...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,728
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_nigbel, pi_puebel, dxy_nigbel_puebel, Fst_nigbe...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,728
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_nigbel, pi_unibel, dxy_nigbel_unibel, Fst_nigbe...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,728
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_nighon, pi_puehon, dxy_nighon_puehon, Fst_nigho...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 110,100
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_nighon, pi_ranhon, dxy_nighon_ranhon, Fst_nigho...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 110,093
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_nighon, pi_unihon, dxy_nighon_unihon, Fst_nigho...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 110,011
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_nigpan, pi_puepan, dxy_nigpan_puepan, Fst_nigpa...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,728
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_nigpan, pi_unipan, dxy_nigpan_unipan, Fst_nigpa...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 110,104
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_puebel, pi_unibel, dxy_puebel_unibel, Fst_puebe...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 110,103
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_puehon, pi_ranhon, dxy_puehon_ranhon, Fst_pueho...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 110,108
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_puehon, pi_unihon, dxy_puehon_unihon, Fst_pueho...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 110,090
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_puepan, pi_unipan, dxy_puepan_unipan, Fst_puepa...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 110,095
## Cols: 9
## chr [1]: scaffold
## dbl [8]: start, end, mid, sites, pi_ranhon, pi_unihon, dxy_ranhon_unihon, Fst_ranho...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
```

From this data, we compute the divergence difference ($\Delta d_{XY}$).


```r
dxy_summary <- dxy_data %>%
  group_by(GPOS) %>%
  summarise(delta_dxy = max(dxy)-min(dxy),
            sd_dxy = sd(dxy),
            delt_pi = max(c(max(PI_POP1),max(PI_POP2))) - min(c(min(PI_POP1),min(PI_POP2)))) %>%
  ungroup() %>%
  setNames(., nm = c('GPOS',
                     str_c('bold(',project_case('e'),'):Delta~italic(d[xy])'),
                     str_c('bold(',project_case('e'),'):italic(d[xy])~(sd)'),
                     str_c('bold(',project_case('e'),'):Delta~italic(pi)'))) %>%
  gather(key = 'window', value = 'value',2:4) %>%
  filter(window == str_c('bold(',project_case('e'),'):Delta~italic(d[xy])'))
```

Then we import the genotype $\times$ phenotype association data.
For this, we list all the traits we want to include and then iterate the import funtion over all traits.
We combine the data sets and transform the table to *long* format.


```r
# import G x P data
traits <- c("Bars.lm.50k.5k.txt.gz", "Peduncle.lm.50k.5k.txt.gz", "Snout.lm.50k.5k.txt.gz")

trait_panels <- c(Bars = str_c('bold(',project_case('h'),')'),
                  Peduncle = str_c('bold(',project_case('i'),')'),
                  Snout = str_c('bold(',project_case('j'),')'))


gxp_data <- str_c(gxp_dir,traits) %>% 
  purrr::map(get_gxp) %>%
  join_list() %>% 
  gather(key = 'window', value = 'value',2:4)
```

```
## Rows: 111,943
## Cols: 11
## chr [ 1]: CHROM
## dbl [10]: BIN_START, BIN_END, N_SNPs, MID_POS, BIN_RANK, BIN_NR, SNP_DENSITY, AVG_p_w...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,943
## Cols: 11
## chr [ 1]: CHROM
## dbl [10]: BIN_START, BIN_END, N_SNPs, MID_POS, BIN_RANK, BIN_NR, SNP_DENSITY, AVG_p_w...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 111,943
## Cols: 11
## chr [ 1]: CHROM
## dbl [10]: BIN_START, BIN_END, N_SNPs, MID_POS, BIN_RANK, BIN_NR, SNP_DENSITY, AVG_p_w...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
```

Then, we import the genome wide $F_{ST}$ summary for all 28 pair wise comparisons to be able to pick a divergence data set of an intermediatly differentiated species pair (the species pair of rank 15, close to 14.5 - the median of rank 1 to 28).


```r
# import genome wide Fst data summary  --------
globals <- vroom::vroom(global_fst_file, delim = '\t',
                      col_names = c('loc','run','mean','weighted')) %>%
  mutate(run = str_c(str_sub(run,1,3),loc,'-',str_sub(run,5,7),loc),
         run = fct_reorder(run,weighted)) 
```

```
## Rows: 28
## Cols: 4
## chr [2]: loc, run
## dbl [2]: mean, weighted
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
```

```r
# select dxy data
selectors_dxy <- globals %>% 
  arrange(weighted) %>% 
  .$weighted %>% 
  .[15]

select_dxy_runs <- globals %>%
  filter(weighted %in% selectors_dxy) %>%
  .$run %>% as.character()

dxy_select <- dxy_data %>% 
  filter(run %in% select_dxy_runs) %>%
  mutate(window = str_c('bold(',project_case('d'),'): italic(d[XY])'))
```

The $d_{XY}$ data set includes also $\pi$ of the involved populations.
We first extract the diversity data for each population (pop1 & pop2), combine them and compute the statistics needed for ranking the populations based on their diversity.


```r
# select pi data
pi_summary_1 <- dxy_data %>%
  group_by(pop1,run) %>%
  summarise(avg_pi = mean(PI_POP1)) %>%
  ungroup() %>%
  set_names(., nm = c('pop','run','avg_pi'))

pi_summary <- dxy_data %>%
  group_by(pop2,run) %>%
  summarise(avg_pi = mean(PI_POP2)) %>%
  ungroup() %>%
  set_names(., nm = c('pop','run','avg_pi')) %>%
  bind_rows(pi_summary_1)  %>%
  group_by(pop) %>% 
  summarise(n = length(pop),
            mean_pi = mean(avg_pi),
            min_pi = min(avg_pi),
            max_pi = max(avg_pi),
            sd_pi = sd(avg_pi)) %>%
  arrange(n)
```

Then, we determine an intermediatly diverse candidate of our 14 populations (rank 7, again: $7 \approx median(1:14)$) and average over the diversities estimated in all pairwise comparisons this population was involved in.


```r
selectors_pi <- pi_summary %>%
  .$mean_pi %>%
  sort() %>%
  .[7]

select_pi_pops <- pi_summary %>%
  filter(mean_pi %in% selectors_pi) %>%
  .$pop %>% as.character

pi_data_select <- dxy_data %>% 
  select(GPOS, PI_POP1, pop1 )%>%
  set_names(., nm = c('GPOS','pi','pop')) %>%
  bind_rows(.,dxy_data %>% 
              select(GPOS, PI_POP2, pop2 )%>%
              set_names(., nm = c('GPOS','pi','pop'))) %>%
  group_by(GPOS,pop) %>% 
  summarise(n = length(pop),
            mean_pi = mean(pi),
            min_pi = min(pi),
            max_pi = max(pi),
            sd_pi = sd(pi)) %>%
  filter(pop %in% select_pi_pops) %>%
  mutate(window = str_c('bold(',project_case('b'),'): italic(pi)'))
```

The import of the recombination data is pretty sraight foreward:
Reading one file, adding genomic position and window coluumn for facetting.


```r
# import recombination data
recombination_data <- vroom::vroom(recombination_file,delim = '\t') %>%
  add_gpos() %>%
  mutate(window = str_c('bold(',project_case('c'),'): rho'))
```

```
## Rows: 11,206
## Cols: 4
## chr [1]: CHROM
## dbl [3]: BIN_START, BIN_END, RHO
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
```

Then we import the topology weighting data. 
This is done once per location, the data sets are combined and specific columns are selected:
The gnomic position, the topologie number (format: three digits with leading zeros, hence "topo3"), relative topology rank ranging from 0 to 1, the facceting column annd the actual weight data.

We also create a dummy tibble that contains the null expectation of the topology weight for the two locations (1/n, with n = number of possible topologies - n = 15 for Belize and 105 for Honduras).


```r
# import topology weighting data
twisst_data <- tibble(loc = c('bel','hon'),
                      panel = c('f','g') %>% project_case() %>% str_c('bold(',.,')')) %>%
  purrr::pmap(match_twisst_files) %>%
  bind_rows() %>% 
  select(GPOS, topo3,topo_rel,window,weight)
```

```
## Rows: 5,102
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,102
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,979
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,979
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,580
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,580
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,781
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,781
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,541
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,541
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,750
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,750
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,867
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,867
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,221
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,221
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,197
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,197
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,745
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,745
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,472
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,472
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,321
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,321
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,158
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,158
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,846
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,846
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,295
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,295
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,896
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,896
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,575
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,575
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,439
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,439
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,346
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,346
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,952
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,952
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,176
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,176
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 3,122
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 3,122
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,050
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,050
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 3,503
## Cols: 15
## dbl [15]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 3,503
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,408
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,408
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 6,340
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 6,340
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,831
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,831
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,079
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,079
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,778
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,778
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,003
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,003
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,164
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,164
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,463
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,463
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,511
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,511
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,024
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,024
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,741
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,741
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,566
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,566
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,487
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,487
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,115
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,115
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,536
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,536
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,205
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,205
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,898
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,898
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,674
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,674
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,656
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,656
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,236
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 5,236
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,408
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,408
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 3,281
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 3,281
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,248
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 4,248
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 3,700
## Cols: 105
## dbl [105]: topo1, topo2, topo3, topo4, topo5, topo6, topo7, topo8, topo9, topo10, topo1...
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
## Rows: 3,700
## Cols: 6
## chr [1]: scaffold
## dbl [5]: start, end, mid, sites, lnL
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
```

```r
twisst_null <- tibble(window = c(str_c('bold(',project_case('f'),'):~weighting[bel]'),
                                 str_c('bold(',project_case('g'),'):~weighting[hon]')),
                      weight = c(1/15, 1/105))
```

We craete a single data set for $d_{XY}$, $F_{ST}$ and genotype $\times$ phenotype data.


```r
# combine data types --------
data <- bind_rows(dxy_summary, fst_data, gxp_data)
```

Then we load the positions of the the $F_{ST}$ outlier windows, select the focal outliers that will receive individual labels and create a tibnble and two parameters for the label placement within the plot.


```r
# import fst outliers
outliers <- vroom::vroom(outlier_table, delim = '\t')
```

```
## Rows: 18
## Cols: 7
## chr [2]: gid, chrom
## dbl [5]: start, end, gstart, gend, gpos
## 
## Call `spec()` for a copy-pastable column specification
## Specify the column types with `col_types` to quiet this message
```

```r
outlier_pick <- c('LG04_1', 'LG12_2', 'LG12_3')

outlier_label <- outliers %>%
  filter(gid %in% outlier_pick) %>%
  mutate(label = letters[row_number()] %>% project_inv_case(),
         x_shift_label = c(-1,-1.2,1)*10^7,
         gpos_label = gpos + x_shift_label,
         gpos_label2 = gpos_label - sign(x_shift_label) *.5*10^7,
         window = str_c('bold(',project_case('a'),'):joint~italic(F[ST])'))

outlier_y <- .45
outlier_yend <- .475
```

### Plotting

Finally it is time to put the pieces together with one giant `ggplot():`


```r
p_done <- ggplot()+
  # add lg indication in the backgroud
  geom_hypo_LG()+
  # add fst outlier window indication in the background 
  geom_vline(data = outliers, aes(xintercept = gpos), color = outlr_clr)+
  # add outlier label flags
  geom_segment(data = outlier_label, 
               aes(x = gpos, 
                   xend = gpos_label2, y = outlier_y, yend = outlier_yend),
               color = alpha(outlr_clr,1),size = .2)+
  # add outlier labels
  geom_text(data = outlier_label, aes(x = gpos_label, y = outlier_yend, label = label),
            color = alpha(outlr_clr,1), fontface = 'bold')+
  # add fst, delta dxy and gxp data
  geom_point(data = data, aes(x = GPOS, y = value),size = plot_size, color = plot_clr) +
  # add dxy data
  geom_point(data = dxy_select,aes(x= GPOS, y = dxy),size = plot_size, color = plot_clr)+
  # add pi data
  geom_point(data = pi_data_select, aes(x = GPOS, y = mean_pi),size = plot_size, color = plot_clr) +
  # add recombination data (points)
  geom_point(data = recombination_data, aes(x = GPOS, y = RHO),size = plot_size, color = plot_clr) +
  # add recombination data (smoothed)
  geom_smooth(data = recombination_data, aes(x = GPOS, y = RHO, group = CHROM),
              color = 'red', se = FALSE, size = .7) +
  # add topology weighting data
  geom_line(data = twisst_data, aes(x = GPOS, y = weight, color = topo_rel),size = .4) +
  # add topology weighting "null expectation"
  geom_hline(data = twisst_null,aes(yintercept =  weight), color = rgb(1,1,1,.5), size=.4) +
  # color scheme lg indication
  scale_fill_hypo_LG_bg() +
  # layout x ayis
  scale_x_hypo_LG()+
  # color scheme topology weighting
  scale_color_gradient( low = "#f0a830ff", high = "#084082ff", guide = FALSE)+
  # facetting to separate the different stats
  facet_grid(window~.,scales = 'free',switch = 'y', labeller = label_parsed)+
    # tune plot appreance
  theme_hypo()+
  theme(legend.position = 'bottom',
    axis.title = element_blank(),
    strip.background = element_blank(),
    strip.placement = 'outside')
```

<center>
<img src="plot_F2_files/figure-html/unnamed-chunk-16-1.png" width="1065.6" />
</center>

```r
hypo_save(p_done, filename = 'figures/F2.png', 
          width = 297*.95, height = 275*.95, units = 'mm',
          comment = plot_comment)
```

---