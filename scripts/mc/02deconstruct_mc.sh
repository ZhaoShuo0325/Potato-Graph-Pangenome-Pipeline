#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=deconstruct_mc
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate mc_env

HOME="/public/home/zhaoshuo/work1/graph/mc"
RAW_VCF="$HOME/exp1/Sim_01_02_mc/Sim_01_02_mc.vcf.gz"
OUT_PREFIX="Sim_01_02_sv"
OUT_DIR="$HOME/exp1/Sim_01_02_mc/deconstruct"
REF_PREFIX="DM8"
PYTHON_SCRIPT="/public/home/zhaoshuo/work1/graph/pggb/scripts/fix_pggb_vcf.py"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

fix_mc_vcf() {
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
    awk 'BEGIN {OFS="\t"} {
        if ($0 ~ /^##/) { print $0; next; }
        if ($0 ~ /^#CHROM/) {
            # 强制重命名样本列，对齐 Truvari 真集
            print $1,$2,$3,$4,$5,$6,$7,$8,$9,"Sim_01","Sim_02";
            next;
        }
        # 假设列顺序: 10:Sim_01_1, 11:Sim_01_2, 12:Sim_02_1, 13:Sim_02_2
        split($10, gt1, ":"); g1 = (gt1[1] == "." ? "0" : gt1[1]);
        split($11, gt2, ":"); g2 = (gt2[1] == "." ? "0" : gt2[1]);
        split($12, gt3, ":"); g3 = (gt3[1] == "." ? "0" : gt3[1]);
        split($13, gt4, ":"); g4 = (gt4[1] == "." ? "0" : gt4[1]);
        
        n1 = g1 "|" g2; n2 = g3 "|" g4;
        
        # 过滤掉全 0 记录并重置 ID 防止符号干扰
        if (n1 != "0|0" || n2 != "0|0") {
            $3 = "."; 
            print $1,$2,$3,$4,$5,$6,$7,$8,"GT",n1,n2;
        }
    }' | \
    bcftools sort -Oz -o "$output"

    tabix -f -p vcf "$output"
    echo "[$(date +'%H:%M:%S')] 修复完成: $output"
}

# 过滤解构结果
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Filtering Deconstructed VCF -----"
vcfbub --input "$RAW_VCF" -l 0 > "${OUT_PREFIX}_bubbled.vcf"

# 修复并分类 SV (INV/INS/DEL)
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Fixing VCF & Classifying SVs -----"
fix_mc_vcf "${OUT_PREFIX}_bubbled.vcf" "${OUT_PREFIX}_temp.vcf.gz" "$REF_PREFIX"

# 压平位点 (处理同一个 POS 下因合并产生的多等位基因，如 1|2)
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Final Normalizing -----"
bcftools norm -m +any "${OUT_PREFIX}_temp.vcf.gz" -Oz -o "${OUT_PREFIX}_final.vcf.gz"
tabix -f -p vcf "${OUT_PREFIX}_final.vcf.gz"

# 最后的统计与过滤验证
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Final Filtering SVs > 50bp -----"
bcftools filter -i 'SVLEN >= 50' "${OUT_PREFIX}_final.vcf.gz" -Oz -o "${OUT_PREFIX}_50bp.vcf.gz"
tabix -f -p vcf "${OUT_PREFIX}_50bp.vcf.gz"

# 打印各类型统计结果
echo "========================================"
echo "SV 统计报告:"
bcftools query -f '%INFO/SVTYPE\n' "${OUT_PREFIX}_50bp.vcf.gz" | sort | uniq -c
echo "总记录数: $(bcftools view -H ${OUT_PREFIX}_50bp.vcf.gz | wc -l)"
echo "========================================"

rm "${OUT_PREFIX}_bubbled.vcf" "${OUT_PREFIX}_temp.vcf.gz"*
