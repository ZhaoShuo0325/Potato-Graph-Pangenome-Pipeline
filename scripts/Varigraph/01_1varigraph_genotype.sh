#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=run_varigraph
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate varigraph_env

d=5 #测序深度
HOME="/public/home/zhaoshuo/work1"
VCF="$HOME/gt/varigraph/vcf_data/Sim_01_02_final.vcf.gz"
GRAPH="$HOME/gt/varigraph/vcf_data/graph.bin"
FQ_DIR="$HOME/data/simulated/short_reads"
REF="$HOME/data/reference/DM8.1_genome.fasta"
OUT_DIR="$HOME/gt/varigraph/exp1/Sim_01_02_vari_d${d}"
SAMPLE_FILE="$OUT_DIR/sample.cfg"

rm  -rf $SAMPLE_FILE
mkdir -p $OUT_DIR
cd $OUT_DIR

# 将样本名称和路径写入sample.txt文件
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Writing sample.txt -----"
for i in {01..02}; do
    FQ1="$FQ_DIR/Sim_${i}_d${d}_PE1.fq.gz"
    FQ2="$FQ_DIR/Sim_${i}_d${d}_PE2.fq.gz"
    echo -e "Sim_${i}\t$FQ1\t$FQ2" >> $SAMPLE_FILE
done

# Performing Genotyping
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Performing Genotyping -----"
varigraph genotype -t 128 \
                   --load-graph $GRAPH \
                   -s $SAMPLE_FILE \
                   --use-depth \
                   --sv \
                   -n 12
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Genotyping Done -----"