#!/usr/bin/bash
# by: Kosmas Hench: 2019-11-29
# usage het_slider <in.het.gz> <Windowsize (bp)> <Increment (bp)>
# -------------------------------------------------------------------------------------------------------------------
# !! beware of awk array size maximum - if the sequence lenght is to big or if the window size & step are to small !!
# !!   (hence, if too many windows are created, the array index maximum is early entries are being overwritten     !!
# -------------------------------------------------------------------------------------------------------------------
# $1 = infile; $2 = windowsize; $3 = increment
j=$(echo $1 | sed 's/.het.gz//g')
WIN=$2;
STEP=$3;
WIN_LAB=$(($WIN/1000));
STEP_LAB=$(($STEP/1000));
RED='\033[0;31m';
NC='\033[0m';

# CHROM	POS	HET	IND

for k in {01..24};do
  echo -e  "--- ${RED}$j${NC} - $k ---"
  echo -e "CHROM\tBIN_START\tBIN_END\tN_SNPs\t$j" > ${j}.${WIN_LAB}k.${STEP_LAB}k.het.tsv

	zcat $1 | grep LG$k | cut -f 1-3 | \
	awk -v OFS="\t" -v w=$WIN -v s=$STEP -v r=$k 'BEGIN{window=w;slide=s;g=0;OL=int(window/slide);}
	{g=int(($2-1)/slide)+1;{for (i=0;i<=OL-1;i++){if(g-i >0){A[g-i]+=$3; B[g-i]++;G[g-i]=g-i;H[g-i]=$1;}}}}
	END{for(i in A){print H[i],(G[i]-1)*slide,(G[i]-1)*slide+window,B[i],A[i]/B[i];k++}}' |
	sort -k2 -n | \
	sed -r '/^\s*$/d' >> ${j}.${WIN_LAB}k.${STEP_LAB}k.het.tsv
done

gzip ${j}.${WIN_LAB}k.${STEP_LAB}k.het.tsv
rm ./$j*.tmp
