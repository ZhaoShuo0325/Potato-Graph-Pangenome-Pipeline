#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=evaluate_pggb
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate truvari_env

HOME="/public/home/zhaoshuo/work1"
TRUTH_VCF_DIR="$HOME/data/simulated/truth_vcf"
QUERY_VCF="$HOME/graph/pggb/exp1/Sim_01_02_total_p98_s10000_n5/deconstruct/pggb_gfa_sv_50bp_1Mb.vcf.gz"
OUT_DIR="$HOME/graph/pggb/exp1/Sim_01_02_total_p98_s10000_n5/deconstruct/evaluate_sv"
GENOME_DIR="$HOME/data/simulated/genomes"
REF_FA="$HOME/data/reference/DM8.1_genome.fasta.gz" # 参考序列

mkdir -p $OUT_DIR
cd $HOME/graph/pggb/exp1/Sim_01_02_total_p98_s10000_n5/deconstruct

# 定义修复函数
# 由于 PGGB 生成的 SVLEN 信息不准确，需要重新计算并注入 Header
fix_vcf() {
    local input=$1
    local output=$2
    # 1. 提取样本并删除旧SVLEN 2. 规范化拆分多等位基因 3. 物理重算SVLEN并注入Header
    bcftools annotate -x INFO/SVLEN "$input" | \
    bcftools norm -m -any --force | \
    awk 'BEGIN {OFS="\t"} 
        /^##/ {print $0; next} 
        /^#CHROM/ {
            print "##INFO=<ID=SVLEN,Number=1,Type=Integer,Description=\"Recalculated SV length\">"; 
            print $0; next
        } 
        {
            ref_len = length($4);
            alt_len = length($5);
            diff = alt_len - ref_len;
            if (diff < 0) diff = -diff; 
            if ($8 == "" || $8 == ".") $8 = "SVLEN=" diff;
            else $8 = $8 ";SVLEN=" diff;
            print $0
        }' | bcftools sort -Oz -o "$output"
    tabix -f -p vcf "$output"
}

# 准备真集 VCF 文件
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Prepare truth VCF files -----"
# VCF 文件需压缩并建立索引
for sample in Sim_01 Sim_02; do
    RAW_TRUTH="$TRUTH_VCF_DIR/${sample}_fixed.vcf"
    FIXED_TRUTH="$OUT_DIR/${sample}_truth.vcf.gz"

    echo "Processing Truth for $sample..."
    fix_vcf "$RAW_TRUTH" "$FIXED_TRUTH"
done