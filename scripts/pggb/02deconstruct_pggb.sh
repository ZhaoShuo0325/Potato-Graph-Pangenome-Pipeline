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
HOME="/path/to/home"
GFA="$HOME/Sim_01_02_total_p98_s10000_n5/Sim_01_02_total.fa.gz.a8a102b.7608fc1.5832edd.smooth.final.gfa"
OUT_PREFIX="pggb_gfa_sv"
REF_PREFIX="DM8"
DECON_DIR="$HOME/Sim_01_02_total_p98_s10000_n5/deconstruct"
mkdir -p "$DECON_DIR"
cd "$DECON_DIR"

# 解构 GFA 文件
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Deconstructing GFA -----"
vg deconstruct -t 24 -P "$REF_PREFIX" -a "$GFA" > "${OUT_PREFIX}_raw.vcf"
# 过滤解构结果
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Filtering Deconstructed VCF -----"
vcfbub --input "${OUT_PREFIX}_raw.vcf" -l 0 -a 100000000 > "${OUT_PREFIX}_bubbled.vcf"

# 修复 VCF 文件
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Fixing Deconstructed VCF -----"
# 1. 提取原始 Header 并添加 SVLEN/SVTYPE 定义，同时移除前缀
grep "^##" "${OUT_PREFIX}_bubbled.vcf" | sed "s/${REF_PREFIX}#0#//g" > fixed_header.vcf
echo '##INFO=<ID=SVLEN,Number=A,Type=Integer,Description="SV length">' >> fixed_header.vcf
echo '##INFO=<ID=SVTYPE,Number=A,Type=String,Description="SV type">' >> fixed_header.vcf
grep "^#CHROM" "${OUT_PREFIX}_bubbled.vcf" | sed "s/${REF_PREFIX}#0#//g" >> fixed_header.vcf
# 2. 处理变异行：计算长度、注入标签、移除前缀
grep -v "^#" "${OUT_PREFIX}_bubbled.vcf" | sed "s/${REF_PREFIX}#0#//g" | awk '
BEGIN {OFS="\t"}
{
    ref_len = length($4);
    alt_len = length($5);
    svlen = alt_len - ref_len;
    svtype = (svlen >= 0 ? "INS" : "DEL");
    
    # 注入到 INFO 列
    $8 = $8 ";SVLEN=" svlen ";SVTYPE=" svtype;
    print $0;
}' > fixed_body.vcf
# 3. 合并并转为标准格式
cat fixed_header.vcf fixed_body.vcf | bcftools sort -Oz -o "${OUT_PREFIX}_final.vcf.gz"
tabix -f -p vcf "${OUT_PREFIX}_final.vcf.gz"
# 4. 清理中间文件
rm fixed_header.vcf fixed_body.vcf

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Deconstructed VCF saved to ${OUT_PREFIX}_final.vcf.gz -----"

# 过滤 >50bp 的 SV
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Filtering SVs > 50bp -----"

bcftools filter -i 'ABS(SVLEN) >= 50' \
    "${OUT_PREFIX}_final.vcf.gz" -Oz -o ${OUT_PREFIX}_50bp.vcf.gz
tabix -f -p vcf ${OUT_PREFIX}_50bp.vcf.gz
bcftools stats ${OUT_PREFIX}_50bp.vcf.gz > ${OUT_PREFIX}_50bp.stats

echo "SVs 记录数: $(zcat ${OUT_PREFIX}_50bp.vcf.gz | grep -v '^#' | wc -l)"
