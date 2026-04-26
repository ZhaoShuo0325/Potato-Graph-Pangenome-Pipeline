#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=run_smoove
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# 环境准备
# source ~/.bashrc
# conda activate smoove_env

d=5 #测序深度
HOME="/public/home/zhaoshuo/work1"
BAM_DIR="$HOME/data/simulated/bam_data"
REF="$HOME/data/reference/DM8.1_genome.fasta"
OUT_DIR="$HOME/call_sv/smoove/exp1/Sim_01_02_d${d}"

rm -rf $OUT_DIR
mkdir -p $OUT_DIR

# 运行delly
for SAMPLE in Sim_01 Sim_02; do
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Running smoove for ${SAMPLE} -----"
    BAM_FILE="$BAM_DIR/${SAMPLE}_d${d}.sorted.bam"
    smoove call \
        -n ${SAMPLE} \
        -f $REF \
        -o $OUT_DIR \
        --genotype \
        --duphold \
        --processes 64 \
        $BAM_FILE
done
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- All smoove jobs have been finished -----"
