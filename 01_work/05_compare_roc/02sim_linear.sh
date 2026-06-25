#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --cpus-per-task=128
#SBATCH --job-name=sim_liner
#SBATCH --output=%x.out
#SBATCH --error=%x.err

HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.ori.chr.fa"
NAME="linear"
SAMPLE_NAME="C098"
OUT_DIR="$HOME/merge_test/04_compare/02sim_linear"
VG="$OUT_DIR/${NAME}.vg"
GBWT="$OUT_DIR/${NAME}.gbwt"
XG="$OUT_DIR/${NAME}.xg"
GBZ="$OUT_DIR/${NAME}.gbz"
DIST="$OUT_DIR/${NAME}.dist"
MIN="$OUT_DIR/${NAME}.min"
ZIP="$OUT_DIR/${NAME}.zipcodes"
f1="$HOME/simulation/varsim_out/${SAMPLE_NAME}/${SAMPLE_NAME}_read1.fq.gz"
f2="$HOME/simulation/varsim_out/${SAMPLE_NAME}/${SAMPLE_NAME}_read2.fq.gz"

mkdir -p $OUT_DIR

vg construct -r $REF -R "chr02" -t 128 -a -p > $VG
vg index -t 128 -x $XG $VG
vg gbwt --num-jobs 128 -x $XG -P -g $GBZ
vg index -t 128 -j $DIST $GBZ
vg minimizer -t 128 -d $DIST -o $MIN -z $ZIP $GBZ

vg sim -r -n 1000000 -l 150 -a -s 12345 -p 570 -v 165 -i 0.00029 -t 128 -x $XG -F $f1 -F $f2 | vg annotate -p -x $XG -a - > $OUT_DIR/linear_${NAME}.gam
vg view -X -a $OUT_DIR/linear_${NAME}.gam | gzip > $OUT_DIR/linear_${NAME}.fastq.gz
vg view -a $OUT_DIR/linear_${NAME}.gam | jq -c -r '[.name] + if (.annotation.features | length) > 0 then [.annotation.features | join(",")] else ["."] end + if .refpos != null then [.refpos[] | .name, if .offset != null then .offset else 0 end] else [] end + [.score] + if .mapping_quality == null then [0] else [.mapping_quality] end | @tsv' > $OUT_DIR/true_${NAME}.pos
vg giraffe -Z $GBZ -d $DIST -m $MIN -z $ZIP -f $OUT_DIR/linear_${NAME}.fastq.gz -b fast -t 128 > $OUT_DIR/mapped_${NAME}.gam
vg gamcompare -r 100 -t 128 -s <(vg annotate -t 128 -m -x $XG -a $OUT_DIR/mapped_${NAME}.gam) $OUT_DIR/linear_${NAME}.gam 2>"$OUT_DIR/${NAME}_count_${NAME}.txt" | vg view -aj - > $OUT_DIR/compared_${NAME}.json

CORRECT_COUNT="$(sed -n '1p' $OUT_DIR/${NAME}_count_${NAME}.txt | sed 's/[^0-9]//g')"
SCORE="$(sed -n '2p' $OUT_DIR/${NAME}_count_${NAME}.txt | sed 's/[^0-9\.]//g')"
MAPQ="$(grep mapping_quality\":\ 60 $OUT_DIR/compared_${NAME}.json | wc -l)"
MAPQ60="$(grep -v correctly_mapped $OUT_DIR/compared_${NAME}.json | grep mapping_quality\":\ 60 | wc -l)"
IDENTITY="$(jq '.identity' $OUT_DIR/compared_${NAME}.json | awk '{sum+=$1} END {print sum/NR}')"
GRAPH=chr02
GBWT=liner-ref
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
