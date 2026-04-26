#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=run_manta
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# 环境准备
# source ~/.bashrc
# conda activate manta_env

d=5 #测序深度
HOME="/public/home/zhaoshuo/work1"
BAM_DIR="$HOME/data/simulated/bam_data"
REF="$HOME/data/reference/DM8.1_genome.fasta"
OUT_DIR="$HOME/call_sv/manta/exp1/Sim_01_02_d${d}"

rm -rf $OUT_DIR
mkdir -p $OUT_DIR
cd $OUT_DIR

REF_FIXED=$HOME/call_sv/manta/exp1/DM8.1_genome_fixed.fasta
# 修复fasta文件，使得每行不超过60个字符
if [ ! -f "${REF_FIXED}.fai" ]; then
    echo "Reformatting FASTA..."
    # 步骤：1. 将所有序列合并为单行 2. 每 60 字符强制换行 3. 确保 Header 独立
    sed -e 's/\s\+$//' $REF | awk '!/^>/ { printf "%s", $0; n=1 } /^>/ { if (n) printf "\n"; printf "%s\n", $0; n=0 } END { printf "\n" }' | \
    awk '/^>/ { print $0; next } { gsub(/.{60}/,"&\n"); sub(/\n$/,""); print $0 }' > $REF_FIXED
    
    samtools faidx $REF_FIXED
fi

# 配置命令
for SAMPLE in Sim_01 Sim_02; do
    BAM_FILE="$BAM_DIR/${SAMPLE}_d${d}.sorted.bam"
    RUN_DIR=$OUT_DIR/${SAMPLE}_d${d}
    rm -rf $RUN_DIR
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Running Manta for ${SAMPLE} -----"
    if [ ! -f "${BAM_FILE}.bai" ]; then
        echo "Creating index for $BAM_FILE..."
        samtools index $BAM_FILE
    fi
    configManta.py \
        --bam $BAM_FILE \
        --referenceFasta $REF_FIXED \
        --runDir $RUN_DIR
    python $RUN_DIR/runWorkflow.py \
            -m local \
            -j 32
done
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Manta finished -----"
