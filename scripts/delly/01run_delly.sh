#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=run_delly
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# 环境准备
# source ~/.bashrc
# conda activate delly_env

d=5 #测序深度
HOME="/public/home/zhaoshuo/work1"
BAM_DIR="$HOME/data/simulated/bam_data"
REF="$HOME/data/reference/DM8.1_genome.fasta"
OUT_DIR="$HOME/call_sv/delly/exp1/Sim_01_02_d${d}"

rm -rf $OUT_DIR
mkdir -p $OUT_DIR

# 运行delly
for SAMPLE in Sim_01 Sim_02; do
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Running delly for ${SAMPLE} -----"
    BAM_FILE="$BAM_DIR/${SAMPLE}_d${d}.sorted.bam"
    OUT_BCF="$OUT_DIR/${SAMPLE}_d${d}.bcf"
    OUT_VCF="$OUT_DIR/${SAMPLE}_d${d}.vcf"
    delly call -g $REF -h 128 -o $OUT_BCF $BAM_FILE
    bcftools view $OUT_BCF > $OUT_VCF
    bgzip -c $OUT_VCF > ${OUT_VCF}.gz
    tabix -p vcf ${OUT_VCF}.gz
done
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Done -----"

