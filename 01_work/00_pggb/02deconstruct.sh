#!/bin/bash

HOME="/public/home/zhaoshuo/work1"
GFA="$HOME/01_work/00_pggb/00_pggb_output/group60.chr01.fa.gz.c325321.7608fc1.877f7d9.smooth.final.gfa"
OUT_PREFIX="group60_chr01"
REF_PREFIX="DM8"
OUT_DIR="$HOME/01_work/00_pggb/01_deconstruct"
PYTHON_SCRIPT="$HOME/01_work/scripts/fix_pggb_vcf.py"

fix_pggb_vcf() {
    local input=$1
    local output=$2
    local ref_prefix=$3
    local python_script="$PYTHON_SCRIPT"

    sed "s/${ref_prefix}#0#//g" "$input" | \
    bcftools norm -m -any --force | \
    python3 "$python_script" | \
    bcftools sort -Oz -o "$output"
    
    tabix -f -p vcf "$output"
}

# Deconstruct RAW VCF
vg deconstruct -t 24 -P "$REF_PREFIX" -a "$GFA" > "$OUT_DIR/${OUT_PREFIX}_raw.vcf"

# Filtering Deconstructed VCF
vcfbub --input "$OUT_DIR/${OUT_PREFIX}_raw.vcf" -l 0 -a 100000000 > "$OUT_DIR/${OUT_PREFIX}_bubbled.vcf"

# Fixing VCF & Classifying SVs
fix_pggb_vcf "$OUT_DIR/${OUT_PREFIX}_bubbled.vcf" "$OUT_DIR/${OUT_PREFIX}_final.vcf.gz" "$REF_PREFIX"

# Filtering SVs > 50bp
bcftools filter -i 'SVLEN >= 50' "$OUT_DIR/${OUT_PREFIX}_final.vcf.gz" -Oz -o "$OUT_DIR/${OUT_PREFIX}_50bp.vcf.gz"
tabix -f -p vcf "$OUT_DIR/${OUT_PREFIX}_50bp.vcf.gz"
