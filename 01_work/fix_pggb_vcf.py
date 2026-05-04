#!/usr/bin/env python3
import sys
import edlib # 用于序列比对

def get_rc(seq):
    """计算序列的反向互补"""
    complement = {'A': 'T', 'C': 'G', 'G': 'C', 'T': 'A', 'N': 'N',
                  'a': 't', 'c': 'g', 'g': 'c', 't': 'a', 'n': 'n'}
    return ''.join(complement.get(base, base) for base in reversed(seq))

def get_identity(seq_ref, seq_alt):
    """计算两条等长序列的匹配度"""
    if not seq_ref or not seq_alt: return 0

    # 限制 k 值，使得编辑距离不超过 0.5 * 序列长度
    max_k = int(len(seq_ref) * 0.5)
    result = edlib.align(seq_ref.upper(), seq_alt.upper(), 
                        mode="HW", task="distance", k=max_k)
    if result["editDistance"] == -1: # 表示超过了 k 值
        return 0
    # 计算身份得分：1 - (编辑距离 / 较短序列长度)
    min_l = min(len(seq_ref), len(seq_alt))
    return 1.0 - (result["editDistance"] / min_l)

def process_vcf():
    for line in sys.stdin:
        if line.startswith('##'):
            # 过滤旧定义
            if 'ID=SVLEN' in line or 'ID=SVTYPE' in line: continue
            sys.stdout.write(line)
            continue
        
        if line.startswith('#CHROM'):
            # 注入新 Header
            sys.stdout.write('##INFO=<ID=SVLEN,Number=1,Type=Integer,Description="Length of the SV">\n')
            sys.stdout.write('##INFO=<ID=SVTYPE,Number=1,Type=String,Description="Type of structural variant">\n')
            sys.stdout.write(line)
            continue

        cols = line.strip().split('\t')
        ref, alt = cols[3], cols[4]
        ref_l, alt_l = len(ref), len(alt)
        diff = alt_l - ref_l
        
        sv_type = None
        sv_len = 0

        # --- 1. 先判定 INV ---
        if ref_l >= 50 and alt_l >= 50:
            len_diff_ratio = abs(diff) / max(ref_l, alt_l)
            if len_diff_ratio < 0.25:
                rc_ref = get_rc(ref)
                if get_identity(rc_ref, alt) > 0.6:
                    sv_type = 'INV'
                    sv_len = ref_l

        # --- 2. 判定 INS/DEL ---
        if not sv_type:
            if diff > 0:
                sv_type = 'INS'
                sv_len = diff
            elif diff < 0:
                sv_type = 'DEL'
                sv_len = abs(diff)

        # --- 3. 过滤并输出 ---
        if sv_type and sv_len >= 50:
            tag = f'SVTYPE={sv_type};SVLEN={sv_len}'
            cols[7] = tag if cols[7] in ['.', ''] else f'{tag};{cols[7]}'
            sys.stdout.write('\t'.join(cols) + '\n')

if __name__ == "__main__":
    process_vcf()