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
RAW_VCF="$HOME/exp1/sim_01_02_mc/sim_01_02_mc.vcf.gz"
OUT_PREFIX="sim_01_02_sv"
OUT_DIR="$HOME/exp1/sim_01_02_mc/deconstruct"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

# 过滤解构结果
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Filtering Deconstructed VCF -----"
vcfbub --input "$RAW_VCF" -l 0 > "${OUT_PREFIX}_bubbled.vcf"
# 修复 VCF 文件
# 1. 拆分多等位基因
bcftools norm -m -any ${OUT_PREFIX}_bubbled.vcf -Oz -o ${OUT_PREFIX}_norm.vcf.gz
tabix -f ${OUT_PREFIX}_norm.vcf.gz

# 2. 提取原始 Header 并添加 SVLEN/SVTYPE 定义
bcftools view -h ${OUT_PREFIX}_norm.vcf.gz | grep "^##" > fixed_header.vcf
echo '##INFO=<ID=SVLEN,Number=1,Type=Integer,Description="Length difference">' >> fixed_header.vcf
echo '##INFO=<ID=SVTYPE,Number=1,Type=String,Description="SV type">' >> fixed_header.vcf
bcftools view -h ${OUT_PREFIX}_norm.vcf.gz | grep "^#CHROM" >> fixed_header.vcf

# 3. 处理变异行 计算长度并注入标签
bcftools view -H "${OUT_PREFIX}_norm.vcf.gz" | awk 'BEGIN {OFS="\t"} {
    ref_len = length($4);
    alt_len = length($5);
    diff = alt_len - ref_len;
    
    # 确定类型 INS/DEL
    if (diff > 0) type="INS"; 
    else if (diff < 0) type="DEL"; 
    else type="SNP";
    
    # 将 SVLEN 转为正数（绝对值）
    abs_diff = (diff < 0) ? -diff : diff;
    
    # 将标签注入到 INFO 列 ($8)，使用 abs_diff
    $8 = $8 ";SVLEN=" abs_diff ";SVTYPE=" type;
    print $0;
}' > fixed_body.vcf

cat fixed_header.vcf fixed_body.vcf | bcftools sort -Oz -o "${OUT_PREFIX}_fixed.vcf.gz"
tabix -f -p vcf "${OUT_PREFIX}_fixed.vcf.gz"

# 4. 合并单倍型
bcftools view "${OUT_PREFIX}_fixed.vcf.gz" | awk 'BEGIN {OFS="\t"} {
    if ($0 ~ /^##/) { print $0; next; }
    if ($0 ~ /^#CHROM/) {
        # 强制将表头改为只有 Sim_01 和 Sim_02
        print $1,$2,$3,$4,$5,$6,$7,$8,$9,"Sim_01","Sim_02";
        next;
    }
    
    # 获取 4 个单倍型的基因型 (GT)
    # 假设顺序是 Sim_01_1(10), Sim_01_2(11), Sim_02_1(12), Sim_02_2(13)
    split($10, gt1, ":"); g1 = (gt1[1] == "." ? "0" : gt1[1]);
    split($11, gt2, ":"); g2 = (gt2[1] == "." ? "0" : gt2[1]);
    split($12, gt3, ":"); g3 = (gt3[1] == "." ? "0" : gt3[1]);
    split($13, gt4, ":"); g4 = (gt4[1] == "." ? "0" : gt4[1]);
    
    # 缝合为二倍体格式 (例如 1|1, 1|0)
    new_sim01 = g1 "|" g2;
    new_sim02 = g3 "|" g4;
    
    # 只保留具有变异的行
    if (new_sim01 != "0|0" || new_sim02 != "0|0") {
        print $1,$2,$3,$4,$5,$6,$7,$8,"GT",new_sim01,new_sim02;
    }
}' | bcftools sort -Oz -o "${OUT_PREFIX}_diploid_raw.vcf.gz"
tabix -f -p vcf "${OUT_PREFIX}_diploid_raw.vcf.gz"

# 4.2 压平重复位置 (Collapse Duplicate POS)
# 有些变异在 H1 和 H2 中是完全重合的，需要把它们压成一行
bcftools norm -m +any "${OUT_PREFIX}_diploid_raw.vcf.gz" -Oz -o "${OUT_PREFIX}_final.vcf.gz"
tabix -f -p vcf "${OUT_PREFIX}_final.vcf.gz"

# 过滤 >50bp 的 SV
bcftools view -i 'ABS(SVLEN) >= 50' \
    ${OUT_PREFIX}_final.vcf.gz -Oz -o "${OUT_PREFIX}_50bp.vcf.gz"
tabix -f "${OUT_PREFIX}_50bp.vcf.gz"
bcftools stats ${OUT_PREFIX}_50bp.vcf.gz > ${OUT_PREFIX}_50bp.stats

