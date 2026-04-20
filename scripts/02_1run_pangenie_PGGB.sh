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
VCF="$HOME/graph/pggb/exp2/nodup_01_02_total_p99_s10000_k47_G500_n5/deconstruct/pggb_gfa_sv_50bp.vcf.gz"
FQ_DIR="$HOME/data/simulated/short_reads"
REF="$HOME/data/reference/DM8.1_genome.fasta"
OUT_DIR="$HOME/gt/pangenie/exp2/nodup_01_02_PGGB_pangenie_d${d}"

mkdir -p $OUT_DIR
TMP_DIR="$OUT_DIR/tmp_unzipped"
mkdir -p $TMP_DIR
# PanGenie 需要未压缩的 VCF 和 FQ 文件
zcat $VCF > $TMP_DIR/pangenome.raw.vcf
# 运行 vcfbub 过滤重叠变异 并再次排序
vcfbub -i "$TMP_DIR/pangenome.raw.vcf" --max-level 0 | \
bcftools sort | \
awk 'BEGIN {OFS="\t"; last_end=0; last_chrom=""} 
    /^#/ {print; next} 
    {
        chrom=$1; start=$2; 
        # 计算该变异在参考基因组上占用的结束位置
        # length($4) 是 REF 列的长度
        end = start + length($4); 

        if (chrom != last_chrom) { 
            last_end = 0; 
            last_chrom = chrom; 
        }

        # 核心逻辑：只有当前变异的起始位置 >= 上一个变异的结束位置，才保留
        if (start >= last_end) {
            print $0;
            last_end = end;
        }
    }' > "$TMP_DIR/pangenome.fixed.vcf"

echo "过滤后剩余位点数: $(grep -v "^#" $TMP_DIR/pangenome.fixed.vcf | wc -l)"

SAMPLES="nodup_01 nodup_02"
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
