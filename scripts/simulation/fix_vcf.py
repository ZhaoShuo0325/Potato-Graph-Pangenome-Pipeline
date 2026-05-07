import os
import subprocess
import sys
import argparse

def get_reverse_complement(seq):
    """计算 DNA 序列的反向互补"""
    complement = {'A': 'T', 'C': 'G', 'G': 'C', 'T': 'A', 'N': 'N',
                  'a': 't', 'c': 'g', 'g': 'c', 't': 'a', 'n': 'n'}
    return "".join(complement.get(base, base) for base in reversed(seq.strip()))

def run_cmd(cmd):
    """执行 Shell 命令"""
    try:
        subprocess.run(cmd, shell=True, check=True)
    except subprocess.CalledProcessError as e:
        print(f" 出错: {e}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="指定前缀自动修复 VCF 和还原 INV 序列")
    parser.add_argument("prefixes", type=str, nargs='+', help="VCF 文件的前缀名 (例如: nodup_01)")
    args = parser.parse_args()

    # 准备映射文件
    chr_map = "chr_map.txt"
    with open(chr_map, "w") as f:
        for i in range(1, 13):
            f.write(f"{i:02d} chr{i:02d}\n")

    # 处理每一个给定的文件
    for s in args.prefixes:
        input_vcf = f"{s}.vcf"
        final_vcf = f"{s}_fixed.vcf"


        if not os.path.exists(input_vcf):
            print(f" 错误: 找不到文件 {input_vcf}")
            sys.exit(1)



        print(f" 正在处理样本: {s}")

        # --- 第一阶段: 结构修复与命名标准化 ---
        tmp_base = f"tmp_{s}_1.vcf"
        tmp_renamed = f"tmp_{s}_2.vcf"
        tmp_sample = f"sample_{s}.txt"

        # 修复 SVLEN, 过滤坐标, 更名染色体
        run_cmd(f"sed 's/ID=SVLEN,Number=1/ID=SVLEN,Number=A/' {input_vcf} | awk '$1~/#/||$2>0' > {tmp_base}")
        run_cmd(f"bcftools annotate --rename-chrs {chr_map} {tmp_base} -Ov -o {tmp_renamed}")
    
        # 修复样本名 (Header)
        with open(tmp_sample, "w") as f:
            f.write(s)
    
        mid_vcf = f"tmp_{s}_mid.vcf"
        run_cmd(f"bcftools reheader --samples {tmp_sample} {tmp_renamed} -o {mid_vcf}")

        # --- 第二阶段: 还原倒位序列 (Python 逻辑) ---
        inv_count = 0
        with open(mid_vcf, 'r') as f_in, open(final_vcf, 'w') as f_out:
            for line in f_in:
                if line.startswith('#'):
                    f_out.write(line)
                    continue
            
                cols = line.split('\t')
                # 识别 INV 变异
                if "<INV>" in cols[4] or "SVTYPE=INV" in cols[7]:
                    cols[4] = get_reverse_complement(cols[3])
                    inv_count += 1
                f_out.write("\t".join(cols))

        # --- 清理样本相关的临时文件 (不删 chr_map) ---
        for tmp in [tmp_base, tmp_renamed, tmp_sample, mid_vcf]:
            if os.path.exists(tmp):
                os.remove(tmp)

        print(f" 处理完成")
        print(f" 还原倒位: {inv_count} 条")
        print(f" 输出文件: {final_vcf}")

if __name__ == "__main__":
    main()
