#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=run_evg
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate evg_env

d=5 #测序深度
HOME="/public/home/zhaoshuo/work1"
VCF="$HOME/graph/vg/exp1/Sim_01_02/deconstruct/Sim_01_02_50bp.vcf.gz"
FQ_DIR="$HOME/data/simulated/short_reads"
REF="$HOME/data/reference/DM8.1_genome.fasta"
OUT_DIR="$HOME/gt/evg/exp1/Sim_01_02_evg_d${d}"
SAMPLE_FILE="$OUT_DIR/sample.txt"

rm  -rf $SAMPLE_FILE
mkdir -p $OUT_DIR

# 将样本名称和路径写入sample.txt文件
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Writing sample.txt -----"

for i in {01..02}; do
    # 定义解压后的路径
    FQ1_UNZ="${OUT_DIR}/Sim_${i}_PE1.fq"
    FQ2_UNZ="${OUT_DIR}/Sim_${i}_PE2.fq"
    
    # 执行解压
    zcat $FQ_DIR/Sim_${i}_d${d}_PE1.fq.gz > $FQ1_UNZ
    zcat $FQ_DIR/Sim_${i}_d${d}_PE2.fq.gz > $FQ2_UNZ
    
    # 写入 sample.txt
    echo -e "Sim_${i} $FQ1_UNZ $FQ2_UNZ" >> $SAMPLE_FILE
done

# 对VCF文件预处理
bcftools norm -d all "$VCF" -o "${OUT_DIR}/input_fixed.vcf"

# 运行EVG
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Running EVG -----"
EVG -r $REF \
    -v ${OUT_DIR}/input_fixed.vcf \
    -s $SAMPLE_FILE \
    --threads 128 \
    --depth $d \
    --software VG-Giraffe GraphAligner GraphTyper2 PanGenie
