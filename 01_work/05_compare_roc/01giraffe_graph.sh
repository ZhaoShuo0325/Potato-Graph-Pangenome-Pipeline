#!/bin/bash

HOME="/public/home/zhaoshuo/work1"
CHR="chr02"
NAME="giraffe"
SAMPLE_NAME="C098"
XG="$HOME/merge_test/02_graph/05_vg_dupfilter/prep/vg_dupfilter_${CHR}.xg"
GBWT="$HOME/merge_test/02_graph/05_vg_dupfilter/${CHR}.gbwt"
MIN="$HOME/merge_test/02_graph/05_vg_dupfilter/prep/vg_dupfilter_${CHR}.min"
GBZ="$HOME/merge_test/02_graph/05_vg_dupfilter/prep/vg_dupfilter_${CHR}.gbz"
DIST="$HOME/merge_test/02_graph/05_vg_dupfilter/prep/vg_dupfilter_${CHR}.dist"
ZIP="$HOME/merge_test/02_graph/05_vg_dupfilter/prep/vg_dupfilter_${CHR}.zipcodes"
OUT_DIR="$HOME/merge_test/04_compare/01_sim_giraffe"
f1="$HOME/simulation/varsim_out/${SAMPLE_NAME}/${SAMPLE_NAME}_read1.fq.gz"
f2="$HOME/simulation/varsim_out/${SAMPLE_NAME}/${SAMPLE_NAME}_read2.fq.gz"

mkdir -p $OUT_DIR
# simulate reads
vg sim -r -n 100000 -l 150 -a -s 12345 -p 570 -v 165 -i 0.00029 -t 128 -x $XG -g $GBWT --sample-name $SAMPLE_NAME -F $f1 -F $f2 | vg annotate -p -x $XG -a - > $OUT_DIR/sim_giraffe.gam

# convert to fastq
vg view -X -a $OUT_DIR/sim_giraffe.gam | gzip > $OUT_DIR/sim_giraffe.fastq.gz

# convert to pos
vg view -a $OUT_DIR/sim_giraffe.gam | jq -c -r '[.name] + if (.annotation.features | length) > 0 then [.annotation.features | join(",")] else ["."] end + if .refpos != null then [.refpos[] | .name, if .offset != null then .offset else 0 end] else [] end + [.score] + if .mapping_quality == null then [0] else [.mapping_quality] end | @tsv' > $OUT_DIR/true_giraffe.pos

# mapping
vg giraffe -Z $GBZ -d $DIST -m $MIN -z $ZIP -f $OUT_DIR/sim_giraffe.fastq.gz -b fast -t 128 > $OUT_DIR/mapped_giraffe.gam

# compare
vg gamcompare -r 100 -t 128 -s <(vg annotate -t 128 -m -x $XG -a $OUT_DIR/mapped_giraffe.gam) $OUT_DIR/sim_giraffe.gam 2>"$OUT_DIR/${CHR}_count_giraffe.txt" | vg view -aj - > $OUT_DIR/compared_giraffe.json

CORRECT_COUNT="$(sed -n '1p' $OUT_DIR/${CHR}_count_giraffe.txt | sed 's/[^0-9]//g')"
SCORE="$(sed -n '2p' $OUT_DIR/${CHR}_count_giraffe.txt | sed 's/[^0-9\.]//g')"
MAPQ="$(grep mapping_quality\":\ 60 $OUT_DIR/compared_giraffe.json | wc -l)"
MAPQ60="$(grep -v correctly_mapped $OUT_DIR/compared_giraffe.json | grep mapping_quality\":\ 60 | wc -l)"
IDENTITY="$(jq '.identity' $OUT_DIR/compared_giraffe.json | awk '{sum+=$1} END {print sum/NR}')"
GRAPH=chr02
GBWT=full
READS=illumina
PARAM_PRESET=default
PAIRING=paired
SPEED=null
printf "graph\tgbwt\treads\tpairing\tspeed\tcorrect\tmapq60\twrong_mapq60\tidentity\tscore\n" > $OUT_DIR/report_giraffe.tsv
printf "correct\tmq\tscore\taligner\n" > $OUT_DIR/roc_stats_giraffe.tsv
echo ${GRAPH} ${GBWT} ${READS} ${PARAM_PRESET}${PAIRING} ${SPEED} ${CORRECT_COUNT} ${MAPQ} ${MAPQ60} ${IDENTITY} ${SCORE}
printf "${GRAPH}\t${GBWT}\t${READS}\t${PARAM_PRESET}\t${PAIRING}\t${SPEED}\t${CORRECT_COUNT}\t${MAPQ}\t${MAPQ60}\t${IDENTITY}\t${SCORE}\n" >> $OUT_DIR/report_giraffe.tsv
jq -r '(if .correctly_mapped then 1 else 0 end|tostring) + "," + (.mapping_quality|tostring) + "," + (.score|tostring)' $OUT_DIR/compared_giraffe.json | sed 's/,/\t/g' | sed "s/$/\tgiraffe_${PARAM_PRESET}_${GRAPH}${GBWT}${READS}${PAIRING}/" >> $OUT_DIR/roc_stats_giraffe.tsv
grep -v 'null' $OUT_DIR/roc_stats_giraffe.tsv > $OUT_DIR/roc_stats_giraffe.ft.tsv
