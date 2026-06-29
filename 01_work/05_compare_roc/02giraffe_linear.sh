#!/bin/bash

HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.ori.chr.fa"
NAME="graph-linear"
SAMPLE_NAME="C098"
OUT_DIR="$HOME/merge_test/04_compare/02sim_linear"
XG="$HOME/merge_test/04_compare/02sim_linear/linear.xg"
MIN="$HOME/merge_test/04_compare/02sim_linear/linear.min"
GBZ="$HOME/merge_test/04_compare/02sim_linear/linear.gbz"
DIST="$HOME/merge_test/04_compare/02sim_linear/linear.dist"
ZIP="$HOME/merge_test/04_compare/02sim_linear/linear.zipcodes"
f1="$HOME/simulation/varsim_out/${SAMPLE_NAME}/${SAMPLE_NAME}_read1.fq.gz"
f2="$HOME/simulation/varsim_out/${SAMPLE_NAME}/${SAMPLE_NAME}_read2.fq.gz"
FQ="$HOME/merge_test/04_compare/01_sim_giraffe/sim_giraffe.fastq.gz"
mkdir -p $OUT_DIR

vg giraffe -Z $GBZ -d $DIST -m $MIN -z $ZIP -f $FQ -b fast -t 128 > $OUT_DIR/mapped_${NAME}.gam
vg view -aj $OUT_DIR/mapped_${NAME}.gam | sed 's/\/1/_1/g' | sed 's/\/2/_2/g' | vg view -aGJ - | vg annotate -m -x $XG -a - | vg gamcompare -r 100 -s - $HOME/merge_test/04_compare/01_sim_giraffe/sim_giraffe.gam 2> $OUT_DIR/${NAME}_count_${NAME}.txt | vg view -aj - > $OUT_DIR/compared_${NAME}.json

CORRECT_COUNT="$(sed -n '1p' $OUT_DIR/${NAME}_count_${NAME}.txt | sed 's/[^0-9]//g')"
SCORE="$(sed -n '2p' $OUT_DIR/${NAME}_count_${NAME}.txt | sed 's/[^0-9\.]//g')"
MAPQ="$(grep mapping_quality\":\ 60 $OUT_DIR/compared_${NAME}.json | wc -l)"
MAPQ60="$(grep -v correctly_mapped $OUT_DIR/compared_${NAME}.json | grep mapping_quality\":\ 60 | wc -l)"
IDENTITY="$(jq '.identity' $OUT_DIR/compared_${NAME}.json | awk '{sum+=$1} END {print sum/NR}')"
GRAPH=chr02
GBWT=graph-linear
READS=illumina
PARAM_PRESET=default
PAIRING=paired
SPEED=null
printf "graph\tgbwt\treads\tpairing\tspeed\tcorrect\tmapq60\twrong_mapq60\tidentity\tscore\n" > $OUT_DIR/report_${NAME}.tsv
printf "correct\tmq\tscore\taligner\n" > $OUT_DIR/roc_stats_${NAME}.tsv
echo ${GRAPH} ${GBWT} ${READS} ${PARAM_PRESET}${PAIRING} ${SPEED} ${CORRECT_COUNT} ${MAPQ} ${MAPQ60} ${IDENTITY} ${SCORE}
printf "${GRAPH}\t${GBWT}\t${READS}\t${PARAM_PRESET}\t${PAIRING}\t${SPEED}\t${CORRECT_COUNT}\t${MAPQ}\t${MAPQ60}\t${IDENTITY}\t${SCORE}\n" >> $OUT_DIR/report_${NAME}.tsv
jq -r '(if .correctly_mapped then 1 else 0 end|tostring) + "," + (.mapping_quality|tostring) + "," + (.score|tostring)' $OUT_DIR/compared_${NAME}.json | sed 's/,/\t/g' | sed "s/$/\tgiraffe_${PARAM_PRESET}_${GRAPH}${GBWT}${READS}${PAIRING}/" >> $OUT_DIR/roc_stats_${NAME}.tsv
grep -v 'null' $OUT_DIR/roc_stats_${NAME}.tsv > $OUT_DIR/roc_stats_${NAME}.ft.tsv
