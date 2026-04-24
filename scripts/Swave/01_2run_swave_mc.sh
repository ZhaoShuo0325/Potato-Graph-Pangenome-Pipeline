#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=run_swave
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate Swave-env

HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.fasta"
GFA="/public/home/zhaoshuo/work1/graph/mc/exp1/sim_01_02_mc/sim_01_02_mc.full.gfa" # 输入的GFA文件
VCF="$HOME/graph/mc/exp1/sim_01_02_mc/deconstruct/Sim_01_02_sv_50bp.vcf.gz"
SAMPLE_DIR="$HOME/data/simulated/genomes"
OUT_DIR="$HOME/graph/swave/exp1/Sim_01_02_swave"
SWAVE="/public/home/zhaoshuo/software/Swave/Swave.py"

rm -rf $OUT_DIR
mkdir -p $OUT_DIR
cd $OUT_DIR

# 将 INFO 中的 AT 标签内容提取并填入 ID 列（第三列），解决 Swave TypeError 问题
FIXED_VCF="$OUT_DIR/Sim_01_02_sv_fixed_id.vcf.gz"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Preprocessing VCF: Moving AT to ID column -----"

zcat $VCF | awk 'BEGIN{OFS="\t"} {
    if($0 ~ /^#/) {print $0} 
    else {
        match($8, /AT=([^;]+)/, a); 
        if(a[1] != "") $3 = a[1]; 
        print $0
    }
}' | bgzip > $FIXED_VCF


tabix -p vcf $FIXED_VCF

# 准备 tsv 文件
SAMPLE_TSV="$OUT_DIR/samples.tsv"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Writing sample.txt -----"
echo -e "DM8\t$REF" > $SAMPLE_TSV
for i in {01..02}; do
    echo -e "Sim_${i}\t$SAMPLE_DIR/Sim_${i}_haplotype1.fasta\t$SAMPLE_DIR/Sim_${i}_haplotype2.fasta" >> $SAMPLE_TSV
done

# 运行 Swave call 模块
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Starting Swave Genotyping -----"

python $SWAVE call \
    --input_path $SAMPLE_TSV \
    --ref_path $REF \
    --gfa_source cactus \
    --gfa_path $GFA \
    --decomposed_vcf $FIXED_VCF \
    --output_path $OUT_DIR \
    --thread_num 128

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Swave Call Finished -----"