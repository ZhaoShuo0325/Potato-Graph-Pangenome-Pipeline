#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=01run_pggb
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
#conda activate pggb_env

# 设置变量
HOME="/path/to/home"
REF="$HOME/data/reference/DM8.1_genome.fasta"
ORI_DIR="$HOME/data/simulated/genomes" # 样本基因组路径
OUT_DIR="$HOME/graph/pggb/exp1"
GENOMES_DIR="$OUT_DIR/genomes" # 输出基因组路径
SAMPLE_LIST="Sim_01_h1 Sim_01_h2 Sim_02_h1 Sim_02_h2 DM8.1_genome" # 样本列表
FINAL_FA="$GENOMES_DIR/Sim_01_02_total.fa" # 最终合并的基因组

# Rename by PanSN
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Preparation and rename by PanSN -----"
# 重命名PanSN chr01 -> Sim_01#1#chr01
mkdir -p $GENOMES_DIR
for i in {01..02};do
    for h in 1 2;do
        sed "s/>/>Sim_${i}#${h}#/" $ORI_DIR/Sim_${i}_haplotype${h}.fasta > $GENOMES_DIR/Sim_${i}_h${h}.pansn.fa
    done
done
sed "s/>/>DM8#0#/" "$REF" > "$GENOMES_DIR/DM8.1_genome.pansn.fa" #chr01 -> DM8#0#chr01

# 样本距离分析
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Sample distance analysis -----"
cd $GENOMES_DIR
# 计算mash距离，以确定PGGB建图参数
for i in {01..02};do
    for h in 1 2;do
        mash sketch -k 21 -s 10000 -o $GENOMES_DIR/Sim_${i}_h${h} $GENOMES_DIR/Sim_${i}_h${h}.pansn.fa
    done
done
mash triangle *.msh > Sim_dist.mdist

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Top 5 samples -----"
sed '1d' Sim_dist.mdist | tr '\t' '\n' | grep -v "Sim_" | awk '$1>0' | sort -gr | head -n 5

# 合并基因组
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Merge genomes -----"
rm -f $FINAL_FA 
for SAMPLE in $SAMPLE_LIST; do
    cat ${SAMPLE}.pansn.fa >> $FINAL_FA
done
echo "正在压缩文件并建立索引..."
bgzip -@ 16 $FINAL_FA
samtools faidx ${FINAL_FA}.gz

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Run PGGB -----"
# PGGB建图参数
f=$FINAL_FA.gz
p=98 #根据样本距离设置
s=10000
n=5 #样本数量
k=47
G=100,300
ref=$REF
t=64 #线程数 根据样本数量
O=0.001 #覆盖率
POA=asm20 #POA算法 asm20适用于基因组比较
out_dir=$OUT_DIR/$(basename "$FINAL_FA" .fa)_p${p}_s${s}_n${n}

pggb -i $f \
    -o $out_dir \
    -p $p \
    -s $s \
    -n $n \
    -k $k \
    -G $G \
    -t $t \
    -O $O \
    -P $POA \
    -v
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- PGGB finished -----"

