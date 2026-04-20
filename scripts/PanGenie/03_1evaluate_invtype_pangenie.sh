#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=evaluate_type_pangenie
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate truvari_env

d=5 #测序深度
HOME="/public/home/zhaoshuo/work1"
TRUTH_VCF_DIR="$HOME/data/simulated/truth_vcf"
GT_VCF_DIR="$HOME/gt/pangenie/exp2/nodup_01_02_PGGB_pangenie_d${d}"
REF_FA="$HOME/data/reference/DM8.1_genome.fasta.gz" # 参考序列
OUT_DIR="$HOME/gt/pangenie/exp2/nodup_01_02_PGGB_pangenie_d${d}/evauate_type"
REF_PREFIX="DM8"
PYTHON_SCRIPT="/public/home/zhaoshuo/work1/graph/pggb/scripts/fix_pggb_vcf.py"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# 修复 PanGenie 生成的 VCF
fix_pangenie_vcf() {
    local input=$1
    local output=$2
    local ref="$REF_FA" 
    local python_script="$PYTHON_SCRIPT"

    echo "[$(date +'%H:%M:%S')] 正在修复 PanGenie VCF 并识别 INV (已加入 awk 过滤 0/0): $input"

    local sample_name=$(bcftools query -l "$input" | head -n 1)
    [ -z "$sample_name" ] && sample_name="SAMPLE"

    local tmp_vcf=$(mktemp -p .)

    # 1. 重新构建标准 Header (包含 Contig 信息)
    echo "##fileformat=VCFv4.2" > "$tmp_vcf"
    awk '{print "##contig=<ID=" $1 ",length=" $2 ">"}' "${ref}.fai" >> "$tmp_vcf"
    
    # 2. 提取原有 Header 并注入 SV 必须的标签
    bcftools view -h "$input" | grep -v "^##fileformat=" | grep -v "^##contig=" | \
        grep -v "^#CHROM" | grep -v "ID=SVLEN" | grep -v "ID=SVTYPE" >> "$tmp_vcf"
    echo '##INFO=<ID=SVLEN,Number=1,Type=Integer,Description="Difference in length">' >> "$tmp_vcf"
    echo '##INFO=<ID=SVTYPE,Number=1,Type=String,Description="Type of SV">' >> "$tmp_vcf"
    echo -e "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t$sample_name" >> "$tmp_vcf"

    # 3. 数据处理流水线
    # 在 bcftools view -H 后面直接加入你的 awk 过滤逻辑
    { 
        cat "$tmp_vcf"; 
        bcftools view -H "$input" | awk 'BEGIN{OFS="\t"} {if ($10 ~ /^0[\/|]0/ || $10 ~ /^\.[\/|]\./) next; print $0}'; 
    } | \
    bcftools norm -m -any --force | \
    python3 "$python_script" | \
    bcftools sort -Oz -o "$output"

    tabix -f -p vcf "$output"
    rm "$tmp_vcf"
    echo "[$(date +'%H:%M:%S')] PanGenie 修复完成 : $output"
}

# 规范化真集 VCF
fix_truth_vcf() {
    local input=$1
    local output=$2

    bcftools view "$input" | \
    bcftools filter -i 'SVLEN >= 50' | \
    bcftools sort -Oz -o "$output"

    tabix -f -p vcf "$output"
}

# 准备真集 VCF
echo "[$(date +'%H:%M:%S')] ----- Prepare fixed truth VCF -----"
for sample in nodup_01 nodup_02; do
    fix_truth_vcf "$TRUTH_VCF_DIR/${sample}_fixed.vcf" "$OUT_DIR/${sample}_truth_all.vcf.gz"
done

# 准备 PanGenie VCF
echo "[$(date +'%H:%M:%S')] ----- Prepare fixed PanGenie VCF -----"
for sample in nodup_01 nodup_02; do
    fix_pangenie_vcf "$GT_VCF_DIR/${sample}_d${d}_genotyping_genotyping.vcf" "$OUT_DIR/${sample}_pangenie_fixed.vcf.gz"
done

# 分样本评估运行 Truvari
echo "[$(date +'%H:%M:%S')] ----- Running Truvari -----"
SUMMARY_CSV="$OUT_DIR/sv_evaluation_detailed.csv"
# 预设表头
echo "Sample,Type,Recall,Precision,F1,GT_Conc,TP,FP,FN" > "$SUMMARY_CSV"

for sample in nodup_01 nodup_02; do
    echo "[$(date +'%H:%M:%S')] >>> Processing Sample: $sample"
    SAMPLE_FIXED_QUERY="$OUT_DIR/${sample}_pangenie_fixed.vcf.gz"
    SAMPLE_FIXED_TRUTH="$OUT_DIR/${sample}_truth_all.vcf.gz"

    for type in TOTAL INS DEL INV; do
        sub_truth="$OUT_DIR/${sample}_truth_${type}.vcf.gz"
        sub_query="$OUT_DIR/${sample}_query_${type}.vcf.gz"
        tru_out_dir="$OUT_DIR/truvari_${sample}_${type}"
        rm -rf "$tru_out_dir"

        if [ "$type" == "TOTAL" ]; then
            cp "$SAMPLE_FIXED_TRUTH" "$sub_truth"
            cp "$SAMPLE_FIXED_QUERY" "$sub_query"
        else
            # 按类型过滤：INS 或 DEL
            bcftools view -i "INFO/SVTYPE='$type'" "$SAMPLE_FIXED_TRUTH" -Oz -o "$sub_truth"
            bcftools view -i "INFO/SVTYPE='$type'" "$SAMPLE_FIXED_QUERY" -Oz -o "$sub_query"
        fi
        tabix -f -p vcf "$sub_truth" && tabix -f -p vcf "$sub_query"

        # 运行 Truvari
        truvari bench -b "$sub_truth" -c "$sub_query" -f "$REF_FA" -o "$tru_out_dir" \
            --sizemin 50 --pctseq 0.0 --pctsize 0.5 --refdist 1000

        # 解析 JSON 结果
        if [ -f "$tru_out_dir/summary.json" ]; then
            get_val() { 
                grep "\"$1\":" "$tru_out_dir/summary.json" | head -n1 | awk -F': ' '{print $2}' | sed 's/[,[:space:]]//g'
            }

            REC=$(get_val "recall")
            PRE=$(get_val "precision")
            F1=$(get_val "f1")
            GTC=$(get_val "gt_concordance")
            TP=$(get_val "TP-base")
            FP=$(get_val "FP")
            FN=$(get_val "FN")

            echo "$sample,$type,$REC,$PRE,$F1,$GTC,$TP,$FP,$FN" >> "$SUMMARY_CSV"
        else
            echo "$sample,$type,0,0,0,0,0,0,0" >> "$SUMMARY_CSV"
        fi
    done
done

# --- 最终可视化打印 (保持不变) ---
echo -e "\n"
echo "================================= SV EVALUATION REPORT ================================="
awk -F',' 'BEGIN {printf "%-10s | %-6s | %-8s | %-8s | %-8s | %-8s | %-5s | %-5s | %-5s\n", "Sample", "Type", "Recall", "Precis.", "F1", "GT_Conc", "TP", "FP", "FN"; print "---------------------------------------------------------------------------------------"} 
NR>1 {printf "%-10s | %-6s | %-8.4f | %-8.4f | %-8.4f | %-8.4f | %-5d | %-5d | %-5d\n", $1, $2, $3, $4, $5, $6, $7, $8, $9}' "$SUMMARY_CSV"
echo "======================================================================================="
