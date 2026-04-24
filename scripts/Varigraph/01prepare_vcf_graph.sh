#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=prepatation
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# 环境准备
# source ~/.bashrc
# conda activate varigraph_env

HOME="/public/home/zhaoshuo/work1"
VCF_DIR="$HOME/data/simulated/truth_vcf"
OUT_DIR="$HOME/gt/varigraph/vcf_data"
REF_FA="$HOME/data/reference/DM8.1_genome.fasta"

MY_TMP="$OUT_DIR/tmp_cache"
mkdir -p "$MY_TMP"
mkdir -p "$OUT_DIR"

# 清理旧的统计日志
> "$OUT_DIR/skipped_sites.log"

# 1. 循环处理样本：标准化 + 跳过 mismatch
for SAMPLE in Sim_01 Sim_02; do
    echo "[$(date +'%H:%M:%S')] 正在标准化与过滤: $SAMPLE"
    
    # 核心逻辑：
    # sort -T: 指定自定义临时目录
    # norm --check-ref s: 关键！遇到 mismatch 直接跳过该行 (skip)，统计到 log
    # -m -any: 拆分多等位基因为单行，方便后续合并
    bcftools sort -T "$MY_TMP" "$VCF_DIR/${SAMPLE}_fixed.vcf" -Ou | \
    bcftools norm -f "$REF_FA" --check-ref s -m -any -Oz -o "$OUT_DIR/${SAMPLE}_norm.vcf.gz" 2>> "$OUT_DIR/skipped_sites.log"
    
    bcftools index -f -t "$OUT_DIR/${SAMPLE}_norm.vcf.gz"
done

# 2. 合并样本并去冗余
echo "[$(date +'%H:%M:%S')] 正在进行最终合并..."
# --merge all: 保留所有样本变异
# 如果你发现结果里有大量重复位点，可以把 --merge all 改成 -m both
bcftools merge --merge all "$OUT_DIR/Sim_01_norm.vcf.gz" "$OUT_DIR/Sim_02_norm.vcf.gz" -Oz -o "$OUT_DIR/Sim_01_02_final.vcf.gz"

# 3. 建立最终索引
bcftools index -f -t "$OUT_DIR/Sim_01_02_final.vcf.gz"

# 4. 结果统计
echo "------------------------------------------"
echo "处理完成！"
SKIPPED=$(grep -c "Lines skipped" "$OUT_DIR/skipped_sites.log" || echo 0)
FINAL_COUNT=$(bcftools view -H "$OUT_DIR/Sim_01_02_final.vcf.gz" | wc -l)

echo "由于 Mismatch 被跳过的变异总数: $SKIPPED"
echo "最终生成的 VCF 变异总数: $FINAL_COUNT"
echo "结果文件: $OUT_DIR/Sim_01_02_final.vcf.gz"
echo "------------------------------------------"

# 清理临时目录
rm -rf "$MY_TMP"

# Building the Genome Graph
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Building the Genome Graph -----"
varigraph construct -t 128 -r $REF -v $OUT_DIR/Sim_01_02_final.vcf.gz --save-graph $OUT_DIR/Sim_01_01_graph.bin
