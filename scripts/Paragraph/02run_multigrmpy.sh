#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=run_multigrmpy
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# 环境准备
# source ~/.bashrc
# conda activate paragraph_env

d=5 #测序深度
MY_PY="/public/home/zhaoshuo/miniconda3/envs/paragraph_env/bin/python" # 3.11
HOME="/public/home/zhaoshuo/work1"
SCRIPTS="/public/home/zhaoshuo/miniconda3/envs/paragraph_env/bin/multigrmpy.py"
REF="$HOME/data/reference/DM8.1_genome.fasta"
VCF="$HOME/graph/vg/exp1/Sim_01_02/deconstruct/Sim_01_02_50bp.vcf.gz"
SAMPLE_LIST="$HOME/gt/paragraph/exp1/Sim_01_02_d${d}/samples.txt"
OUT_DIR="$HOME/gt/paragraph/exp1/Sim_01_02_d${d}/result"

rm -rf $OUT_DIR
mkdir -p $OUT_DIR

# --- 准备 VCF 并统计过滤情况 ---
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Step 1: Fixing VCF with AWK Filter... -----"
FIXED_VCF="$HOME/gt/paragraph/exp1/Sim_01_02_d${d}/vg_gfa_sv_50bp_fixed.vcf.gz"

# 统计原始位点数 (排除 header)
original_count=$(zcat "$VCF" | grep -v '^#' | wc -l)

# 物理剔除首碱基不匹配的位点
bcftools norm -f "$REF" -m -any "$VCF" 2>/dev/null | \
awk 'BEGIN {OFS="\t"} {
    if ($0 ~ /^#/) { print $0 } 
    else {
        # 提取 REF 和 ALT 的第一个碱基进行对比
        ref_base = substr($4, 1, 1);
        alt_base = substr($5, 1, 1);
        if (ref_base == alt_base) { print $0 }
    }
}' | \
bcftools sort -Oz -o "$FIXED_VCF"

tabix -f -p vcf "$FIXED_VCF"

# 统计过滤后的位点数
final_count=$(zcat "$FIXED_VCF" | grep -v '^#' | wc -l)
dropped_count=$((original_count - final_count))

echo "========================================"
echo "VCF 过滤统计报告:"
echo "原始位点总数: $original_count"
echo "保留位点总数: $final_count"
echo "过滤掉的位点数: $dropped_count"
echo "========================================"

# --- 运行 paragraph ---
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Step 2: Starting Paragraph Multigrmpy... -----"

$MY_PY "$SCRIPTS" \
    -t 64 \
    -i "$FIXED_VCF" \
    -m "$SAMPLE_LIST" \
    -r "$REF" \
    -o "$OUT_DIR"

# 建立索引
tabix -f -p vcf "$OUT_DIR/genotypes.vcf.gz"
tabix -f -p vcf "$OUT_DIR/variants.vcf.gz"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Paragraph Multigrmpy Done. -----"
