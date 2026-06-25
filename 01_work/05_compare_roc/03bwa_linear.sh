#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --cpus-per-task=128
#SBATCH --job-name=bwa_liner
#SBATCH --output=%x.out
#SBATCH --error=%x.err

HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.ori.chr.fa"
NAME="bwa_linear"
FQ="$HOME/merge_test/04_compare/02sim_linear/linear_linear.fastq.gz"
XG="$HOME/merge_test/04_compare/02sim_linear/linear.xg"
OUT_DIR="$HOME/merge_test/04_compare/03bwa_linear"

mkdir -p $OUT_DIR

bwa mem -t 128 $REF $FQ | samtools view -@ 128 -b - | samtools sort -@ 128 -o $OUT_DIR/DM_raw_${NAME}.bam
samtools index -@ 128 $OUT_DIR/DM_raw_${NAME}.bam
samtools view -F 2048 -b $OUT_DIR/DM_raw_${NAME}.bam chr02 > $OUT_DIR/mapped_DM_${NAME}.bam
samtools index -@ 128 $OUT_DIR/mapped_DM_${NAME}.bam
vg inject -x $XG $OUT_DIR/mapped_DM_${NAME}.bam -t 128 > $OUT_DIR/mapped_DM_${NAME}.gam
vg view -aj $OUT_DIR/mapped_DM_${NAME}.gam | sed 's/\/1/_1/g' | sed 's/\/2/_2/g' | vg view -aGJ - | vg annotate -m -x $XG -a - | vg gamcompare -r 100 -s - $HOME/merge_test/04_compare/02sim_linear/linear_linear.gam 2> $OUT_DIR/${NAME}_count_${NAME}.txt | vg view -aj - > $OUT_DIR/compared_${NAME}.json

READS=illumina
PAIRING=paired
SPEED=null
GRAPH=bwa-chr02
ALGORITHM=bwa
GRAPH_NAME=DM_v8.1
CORRECT_COUNT="$(grep correctly_mapped $OUT_DIR/compared_${NAME}.json | wc -l)"
SCORE="$(sed -n '2p' $OUT_DIR/${NAME}_count_${NAME}.txt | sed 's/[^0-9\.]//g')"
MAPQ="$(grep mapping_quality\":\ 60 $OUT_DIR/compared_${NAME}.json | wc -l)"
MAPQ60="$(grep -v correctly_mapped $OUT_DIR/compared_${NAME}.json | grep mapping_quality\":\ 60 | wc -l)"
IDENTITY="$(jq '.identity' $OUT_DIR/compared_${NAME}.json | awk '{sum+=$1} END {print sum/NR}')"
echo ${GRAPH} ${READS} ${PAIRING} ${SPEED} ${CORRECT_COUNT} ${MAPQ} ${MAPQ60} ${SCORE}
printf "${GRAPH}\t${ALGORITHM}\t${READS}\t${PAIRING}\t-\t${CORRECT_COUNT}\t${MAPQ}\t${MAPQ60}\t${IDENTITY}\t${SCORE}\n" >> $OUT_DIR/report_${ALGORITHM}_${NAME}.tsv
jq -r '(if .correctly_mapped then 1 else 0 end|tostring) + "," + (.mapping_quality|tostring) + "," + (.score|tostring)' $OUT_DIR/compared_${NAME}.json | sed 's/,/\t/g' | sed "s/$/\t${ALGORITHM}_${GRAPH}${READS}${PAIRING}/" | sed 's/single//g ; s/paired/-pe/g ; s/null/0/g' >> $OUT_DIR/roc_stats_${ALGORITHM}_${NAME}.tsv
grep -v 'null' $OUT_DIR/roc_stats_${ALGORITHM}_${NAME}.tsv > $OUT_DIR/roc_stats_${ALGORITHM}_${NAME}.ft.tsv
