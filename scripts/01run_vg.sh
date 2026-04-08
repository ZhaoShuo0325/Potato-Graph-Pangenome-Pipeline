#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=01run_vg
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# 环境准备
# source ~/.bashrc
# conda activate vg_env

HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.fasta"
VCF_FILE="$HOME/graph/vg/vcf_data/Sim_01_02_final.vcf.gz"
OUT_DIR="$HOME/graph/vg/exp1/Sim_01_02"

mkdir -p $OUT_DIR

# 构建vg图

vg construct -t 128 \
    -r $REF \
    -v $VCF_FILE \
    -a -p > $OUT_DIR/Sim_01_02_graph.vg

vg view -g $OUT_DIR/Sim_01_02_graph.vg > $OUT_DIR/Sim_01_02_graph.gfa
vg gbwt --num-jobs 128 \
    -x "$OUT_DIR/Sim_01_02_graph.vg" \
    -v "$VCF_FILE" \
    -o "$OUT_DIR/Sim_01_02.gbwt" \
    --vcf-variants \
    --progress