#!/bin/bash

sed 's/50/128/g' work.sh | \
sed 's/256G/256G/g' | \
sed 's/edta/deconstruct/g' | \
sed 's/%j/deconstruct/g' > deconstruct.sh

cat >> deconstruct.sh << 'HEREDOC'
HOME="/public/home/zhaoshuo/work1"
GFA="$HOME/01_work/00_pggb/00_pggb_output/group60.chr01.fa.gz.c325321.7608fc1.877f7d9.smooth.final.gfa"
OUT_PREFIX="group60_chr01"
REF_PREFIX="DM8"
OUT_DIR="$HOME/01_work/00_pggb/01_deconstruct"
PYTHON_SCRIPT="$HOME/01_work/scripts/fix_pggb_vcf.py"

mkdir -p "$OUT_DIR"

fix_pggb_vcf() {
    local input=$1
    local output=$2
    local ref_prefix=$3
    local python_script="$PYTHON_SCRIPT"

    echo "[$(date +'%H:%M:%S')] 正在修复 VCF: $input -> $output"

    sed "s/${ref_prefix}#0#//g" "$input" | \
    bcftools norm -m -any --force | \
    python3 "$python_script" | \
    bcftools sort -Oz -o "$output"

    tabix -f -p vcf "$output"
    echo "[$(date +'%H:%M:%S')] 修复完成: $output"
}

# 解构 RAW VCF
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Deconstructing GFA -----"
vg deconstruct -t 24 -P "$REF_PREFIX" -a "$GFA" > "$OUT_DIR/${OUT_PREFIX}_raw.vcf"

# 过滤嵌套变异 (vcfbub)
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Filtering Deconstructed VCF (vcfbub) -----"
vcfbub --input "$OUT_DIR/${OUT_PREFIX}_raw.vcf" -l 0 -a 100000000 > "$OUT_DIR/${OUT_PREFIX}_bubbled.vcf"

# 修复并分类 SV (INV/INS/DEL)
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Fixing VCF & Classifying SVs -----"
fix_pggb_vcf "$OUT_DIR/${OUT_PREFIX}_bubbled.vcf" "$OUT_DIR/${OUT_PREFIX}_final.vcf.gz" "$REF_PREFIX"

# 统计与过滤验证
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Final Filtering SVs > 50bp -----"
bcftools filter -i 'SVLEN >= 50' "$OUT_DIR/${OUT_PREFIX}_final.vcf.gz" -Oz -o "$OUT_DIR/${OUT_PREFIX}_50bp.vcf.gz"
tabix -f -p vcf "$OUT_DIR/${OUT_PREFIX}_50bp.vcf.gz"

# 打印各类型统计结果
echo "========================================"
echo "SV 统计报告:"
bcftools query -f '%INFO/SVTYPE\n' "$OUT_DIR/${OUT_PREFIX}_50bp.vcf.gz" | sort | uniq -c
echo "总记录数: $(zcat $OUT_DIR/${OUT_PREFIX}_50bp.vcf.gz | grep -v '^#' | wc -l)"
echo "========================================"
rm -rf $OUT_DIR/${OUT_PREFIX}_bubbled.vcf $OUT_DIR/${OUT_PREFIX}_final.vcf.gz

HEREDOC
sbatch deconstruct.sh