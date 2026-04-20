#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=run_vg_call
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# 环境准备
# source ~/.bashrc
# conda activate vg_env

d=5 # 测序深度
HOME="/public/home/zhaoshuo/work1"
GBZ="$HOME/gt/giraffe/exp2/data/nodup_01_02_PGGB.gbz"
GAF_DIR="$HOME/gt/giraffe/exp2/nodup_01_02_PGGB_giraffe_d${d}"
OUT_DIR="$GAF_DIR/vg_call"
PYTHON_SCRIPT="/public/home/zhaoshuo/work1/graph/pggb/scripts/fix_pggb_vcf.py"
REF_PREFIX="DM8"
SAMPLES="nodup_01 nodup_02"

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

fix_pggb_vcf() {
    local input=$1
    local output=$2
    local ref_prefix=$3
    
    local python_script="$PYTHON_SCRIPT"

    echo "[$(date +'%H:%M:%S')] 正在修复 VCF: $input -> $output"

    # 管道调用：sed -> bcftools -> 你的外部python脚本 -> bcftools sort
    sed "s/${ref_prefix}#0#//g" "$input" | \
    bcftools norm -m -any --force | \
    python3 "$python_script" | \
    bcftools sort -Oz -o "$output"

    tabix -f -p vcf "$output"
    echo "[$(date +'%H:%M:%S')] 修复完成: $output"
}

# ---  vg pack (计算覆盖度) ---
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Phase 1: Packing -----"
for SAMPLE in $SAMPLES; do
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Processing $SAMPLE"
    vg pack -t 128 -e \
        -x "$GBZ" \
        -a "$GAF_DIR/${SAMPLE}_giraffe.gaf" \
        -o "$OUT_DIR/${SAMPLE}.pack"
done

# ---  vg call (生成原始 VCF) ---
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Phase 2: Calling -----"
for SAMPLE in $SAMPLES; do
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Calling $SAMPLE"
    vg call -t 128 -z "$GBZ" -k "$OUT_DIR/${SAMPLE}.pack" -s "$SAMPLE" > "${SAMPLE}.raw.vcf"
done

# --- 步骤 3: 修复、分类与过滤 (50bp) ---
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Phase 3: Fixing & Filtering -----"
for SAMPLE in $SAMPLES; do
    RAW_VCF="${SAMPLE}.raw.vcf"
    FINAL_VCF="${SAMPLE}_final.vcf.gz"
    FILTERED_VCF="${SAMPLE}_50bp.vcf.gz"

    # 调用修复函数
    fix_pggb_vcf "$RAW_VCF" "$FINAL_VCF" "$REF_PREFIX"

    # 过滤 50bp 以上的变异
    echo "[$(date +'%H:%M:%S')] Filtering > 50bp for $SAMPLE"
    bcftools filter -i 'SVLEN >= 50 || SVLEN <= -50' "$FINAL_VCF" -Oz -o "$FILTERED_VCF"
    tabix -f -p vcf "$FILTERED_VCF"

    # 打印单个样本统计
    echo "Summary for $SAMPLE (>= 50bp):"
    bcftools query -f '%INFO/SVTYPE\n' "$FILTERED_VCF" | sort | uniq -c
    echo "-----------------------------------------------"
done

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- All Processes Complete -----"
