#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=deconstruct_pggb
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate pggb_env

# 设置变量
HOME="/public/home/zhaoshuo/work1/graph/pggb/exp1"
GFA="$HOME/Sim_01_02_total_p98_s10000_n5/Sim_01_02_total.fa.gz.a8a102b.7608fc1.5832edd.smooth.final.gfa" #调整GFA路径
OUT_PREFIX="pggb_gfa_sv"
REF_PREFIX="DM8"
DECON_DIR="$HOME/Sim_01_02_total_p98_s10000_n5/deconstruct" #调整输出路径
PYTHON_SCRIPT="/public/home/zhaoshuo/work1/graph/pggb/scripts/fix_pggb_vcf.py"


mkdir -p "$DECON_DIR"
cd "$DECON_DIR"

fix_pggb_vcf() {
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
    bcftools sort -Oz -o "$output"

    tabix -f -p vcf "$output"
    echo "[$(date +'%H:%M:%S')] 修复完成: $output"
}

# 解构 RAW VCF
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Deconstructing GFA -----"
vg deconstruct -t 24 -P "$REF_PREFIX" -a "$GFA" > "${OUT_PREFIX}_raw.vcf"

# 过滤嵌套变异 (vcfbub)
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Filtering Deconstructed VCF (vcfbub) -----"
vcfbub --input "${OUT_PREFIX}_raw.vcf" -l 0 -a 100000000 > "${OUT_PREFIX}_bubbled.vcf"

# 修复并分类 SV (INV/INS/DEL)
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Fixing VCF & Classifying SVs -----"
fix_pggb_vcf "${OUT_PREFIX}_bubbled.vcf" "${OUT_PREFIX}_final.vcf.gz" "$REF_PREFIX"

# 最后的统计与过滤验证
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Final Filtering SVs > 50bp -----"
bcftools filter -i 'SVLEN >= 50' "${OUT_PREFIX}_final.vcf.gz" -Oz -o "${OUT_PREFIX}_50bp.vcf.gz"
tabix -f -p vcf "${OUT_PREFIX}_50bp.vcf.gz"

# 打印各类型统计结果
echo "========================================"
echo "SV 统计报告:"
bcftools query -f '%INFO/SVTYPE\n' "${OUT_PREFIX}_50bp.vcf.gz" | sort | uniq -c
echo "总记录数: $(zcat ${OUT_PREFIX}_50bp.vcf.gz | grep -v '^#' | wc -l)"
echo "========================================"
