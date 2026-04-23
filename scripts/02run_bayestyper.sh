#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=run_bayestyper
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# 环境准备
# source ~/.bashrc
# conda activate bt_env

d=5 #测序深度
HOME="/public/home/zhaoshuo/work1"
FQ_DIR="$HOME/data/simulated/short_reads"
KMC_DIR="$HOME/gt/bayestyper/exp1/Sim_01_02_d${d}"
OUT_DIR="$HOME/gt/bayestyper/exp1/Sim_01_02_d${d}/result"
REF="$HOME/data/reference/DM8.1_genome.fasta"
VCF="$HOME/graph/vg/exp1/Sim_01_02/deconstruct/Sim_01_02_50bp.vcf.gz"

rm -rf $OUT_DIR
mkdir -p $OUT_DIR
cd $KMC_DIR

# 生成样本 tsv 文件
TSV="$OUT_DIR/samples.tsv"
for SAMPLE in Sim_01 Sim_02; do
    echo -e "${SAMPLE}\tF\t${KMC_DIR}/${SAMPLE}_kmc" >> $TSV
done

# 修复 VCF 文件
CLEAN_VCF="$OUT_DIR/Sim_01_02_50bp_clean.vcf.gz"
bcftools annotate -x ID $VCF | \
bcftools norm -m +any -f $REF | \
bcftools sort -Ov | gzip > $CLEAN_VCF
cd $OUT_DIR
# 运行 bayesTyper cluster
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Running bayesTyper cluster -----"
bayesTyper cluster -v $CLEAN_VCF -s $TSV -g $REF -p 64

# 运行 bayesTyper genotype
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Running bayesTyper genotype -----"
bayesTyper genotype -v $OUT_DIR/bayestyper_unit_1/variant_clusters.bin \
                    -c $OUT_DIR/bayestyper_cluster_data \
                    -s $TSV \
                    -g $REF \
                    -o $OUT_DIR/bayestyper_genotype \
                    -z -p 128

bcftools view -f PASS -i 'GT~"1"' $OUT_DIR/bayestyper_genotype.vcf.gz -Oz -o $OUT_DIR/Sim_01_02_final_genotype.vcf.gz