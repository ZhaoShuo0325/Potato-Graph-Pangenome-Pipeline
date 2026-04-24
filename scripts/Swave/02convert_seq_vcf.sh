#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=convert_seq_vcf
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate Swave-env

HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.fasta"
GFA="/public/home/zhaoshuo/work1/graph/vg/exp1/Sim_01_02/Sim_01_02_graph.gfa" # 输入的GFA文件
WORK_DIR="$HOME/graph/swave/exp1/Sim_01_02_swave_vg"
SWAVE="/public/home/zhaoshuo/software/Swave/Swave.py"
FAI_PATH="$REF.fai"
OUT_DIR="$HOME/graph/swave/exp1/Sim_01_02_swave_vg/fixed_sv"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Step 1: Pre-processing VCF -----"

awk 'BEGIN {OFS="\t"} {
    if ($1 ~ /^#/) { 
        gsub(/DM8#0#/, "", $0);
        print $0; 
    } 
    else {
        gsub(/DM8#0#/, "", $1); # 去掉 CHROM 列的前缀
        # 修正 ID 格式
        if (match($3, /[><][0-9]+/)) {
            $3 = substr($3, RSTART, RLENGTH); 
        }
        # 过滤长度
        if (match($8, /SVLEN=-?[0-9]+/)) {
            # 提取绝对值处理 DEL/INS
            split(substr($8, RSTART+6), a, ";");
            len = a[1];
            if (len < 0) len = -len;
            if (len >= 50) { print $0 }
        }
    }
}' "$WORK_DIR/swave.sample_level.split.vcf" > "$OUT_DIR/Sim_01_02_50bp_tmp.vcf"

bcftools view -s ^DM8 "$OUT_DIR/Sim_01_02_50bp_tmp.vcf" -o "$OUT_DIR/Sim_01_02_noDM8.vcf"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Step 2: Fixing Header & Indexing -----"

bcftools reheader --fai "$FAI_PATH" "$OUT_DIR/Sim_01_02_noDM8.vcf" > "$OUT_DIR/Sim_01_02_50bp_std.vcf"
bgzip -f "$OUT_DIR/Sim_01_02_50bp_std.vcf"
tabix -f -p vcf "$OUT_DIR/Sim_01_02_50bp_std.vcf.gz"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Step 3: Running Swave convert_seq -----"

python "$SWAVE" convert_seq \
    --vcf_path "$OUT_DIR/Sim_01_02_50bp_std.vcf.gz" \
    --gfa_path "$GFA" \
    --ref_path "$REF" \
    --output_path "$OUT_DIR" \
    --force_pangenie

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- All Done! -----"