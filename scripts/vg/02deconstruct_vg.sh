#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=deconstruct_vg
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate vg_env

HOME="/public/home/zhaoshuo/work1/graph/vg/exp1/Sim_01_02"
VG_FILE="$HOME/Sim_01_02_graph.vg"
OUT_PREFIX="Sim_01_02"
DECON_DIR="$HOME/deconstruct"
GBWT="$HOME/Sim_01_02.gbwt"
REF_PREFIX="DM8"
PYTHON_SCRIPT="/public/home/zhaoshuo/work1/graph/pggb/scripts/fix_pggb_vcf.py"

rm -rf "$DECON_DIR"
mkdir -p "$DECON_DIR"
cd "$DECON_DIR"

# 解构 RAW VCF
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Deconstructing GFA -----"

vg snarls -t 24 $VG_FILE > "$OUT_PREFIX".snarls
SNARLS="$DECON_DIR/$OUT_PREFIX.snarls"

vg paths -L -v "$VG_FILE" | grep -v "_alt_" | grep -v "nodup_" | tr -d '\r' > clean_ref_paths.txt
P_ARGS=$(sed 's/^/-p /' clean_ref_paths.txt | tr '\n' ' ')
vg deconstruct -t 128 -g "$GBWT" -r "$SNARLS" $P_ARGS "$VG_FILE" | \
bcftools view -s nodup_01,nodup_02 -o ${OUT_PREFIX}_raw.vcf
bcftools stats ${OUT_PREFIX}_raw.vcf > ${OUT_PREFIX}_raw.stats

fix_pggb_vcf() {
    local input=$1
    local output=$2
    local ref_prefix=$3
    
    # 获取 Python 脚本的绝对路径，确保在不同目录下都能找到
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

# 修复并分类 SV (INV/INS/DEL)
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Fixing VCF & Classifying SVs -----"
fix_pggb_vcf "${OUT_PREFIX}_raw.vcf" "${OUT_PREFIX}_final.vcf.gz" "$REF_PREFIX"

# 最后的统计与过滤验证
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Final Filtering SVs > 50bp -----"
bcftools filter -i 'SVLEN >= 50' "${OUT_PREFIX}_final.vcf.gz" -Oz -o "${OUT_PREFIX}_50bp.vcf.gz"
tabix -f -p vcf "${OUT_PREFIX}_50bp.vcf.gz"

# 打印各类型统计结果
echo "========================================"
echo "SV 统计报告:"
bcftools query -f '%INFO/SVTYPE\n' "${OUT_PREFIX}_50bp.vcf.gz" | sort | uniq -c
echo "总记录数: $(zcat ${OUT_PREFIX}_50bp.vcf.gz | grep -v '^#' | wc -l)"
echo "========================================"
