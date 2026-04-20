#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=run_pangenie
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate pangenie_env

d=5 #测序深度
HOME="/public/home/zhaoshuo/work1"
VCF="$HOME/graph/vg/exp1/Sim_01_02/deconstruct/Sim_01_02_50bp.vcf.gz"
FQ_DIR="$HOME/data/simulated/short_reads"
REF="$HOME/data/reference/DM8.1_genome.fasta"
OUT_DIR="$HOME/gt/pangenie/exp1/Sim_01_02_vg_pangenie_d${d}"

rm -rf $OUT_DIR
mkdir -p $OUT_DIR
TMP_DIR="$OUT_DIR/tmp_unzipped"
mkdir -p $TMP_DIR
# PanGenie 需要未压缩的 VCF 和 FQ 文件
zcat $VCF > $TMP_DIR/pangenome.raw.vcf

bcftools annotate -x INFO/LV "$TMP_DIR/pangenome.raw.vcf" | \
bcftools sort > "$TMP_DIR/pangenome.sorted.vcf"
awk 'BEGIN {OFS="\t"; last_end=0; last_chrom=""} 
    /^#/ {print; next} 
    {
        chrom=$1; start=$2; 
        ref_len = length($4); 
        if (chrom != last_chrom) { last_end = 0; last_chrom = chrom; }
        if (start >= last_end) {
            print $0;
            last_end = start + ref_len;
        }
    }' "$TMP_DIR/pangenome.sorted.vcf" > "$TMP_DIR/pangenome.fixed.vcf"
echo "最终过滤后位点数: $(grep -v "^#" "$TMP_DIR/pangenome.fixed.vcf" | wc -l)"

SAMPLES="Sim_01 Sim_02"
# 运行 PanGenie
for SAMPLE in $SAMPLES; do
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- 正在解压并合并 Reads... -----"
    zcat $FQ_DIR/${SAMPLE}_d${d}_PE1.fq.gz $FQ_DIR/${SAMPLE}_d${d}_PE2.fq.gz > $TMP_DIR/${SAMPLE}_d${d}_combined.fq
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- 正在运行 PanGenie... -----"
    PanGenie -t 128 -j 64 \
        -i $TMP_DIR/${SAMPLE}_d${d}_combined.fq \
        -r $REF \
        -v $TMP_DIR/pangenome.fixed.vcf \
        -o $OUT_DIR/${SAMPLE}_d${d}_genotyping \
        -s $SAMPLE
    rm -rf $TMP_DIR/${SAMPLE}_d${d}_combined.fq
done

rm -rf $TMP_DIR
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- 运行 PanGenie 完成！ -----"
