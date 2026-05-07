import os, subprocess, sys, argparse, re, pysam

DEFAULT_REF = "/public/home/zhaoshuo/work1/data/reference/DM8.1_genome.ori.chr.fa"

def get_rc(seq):
    cp = str.maketrans('ACGTNacgtn', 'TGCANtgcan')
    return seq.translate(cp)[::-1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("prefixes", nargs='+')
    args = parser.parse_args()

    ref_fa = pysam.FastaFile(DEFAULT_REF)
    with open("chr_map.txt", "w") as f:
        for i in range(1, 13): f.write(f"{i:02d} chr{i:02d}\n")

    for s in args.prefixes:
        if not os.path.exists(f"{s}.vcf"): continue
        
        tmp_vcf = f"tmp_{s}.vcf"
        cmd = (f"sed 's/ID=SVLEN,Number=1/ID=SVLEN,Number=A/' {s}.vcf | awk '$1~/#/||$2>0' | "
               f"bcftools annotate --rename-chrs chr_map.txt | "
               f"bcftools reheader --samples <(echo {s}) -o {tmp_vcf}")
        subprocess.run(cmd, shell=True, check=True, executable='/bin/bash')

        with open(tmp_vcf, 'r') as f_in, open(f"{s}_fixed.vcf", 'w') as f_out:
            for line in f_in:
                if line.startswith('#'):
                    f_out.write(line); continue
                
                c = line.split('\t')
                chrom, pos, ref, info = c[0], int(c[1]), c[3], c[7]
                svlen = abs(int(m.group(1))) if (m := re.search(r'SVLEN=(-?\d+)', info)) else 0

                if "SVTYPE=INV" in info or "<INV>" in c[4]:
                    seq = ref if len(ref) > 1 else ref_fa.fetch(chrom, pos-1, pos-1+svlen)
                    c[4] = get_rc(seq)
                elif "SVTYPE=DUP:TANDEM" in info:
                    if svlen > 0:
                        c[4] = ref + ref_fa.fetch(chrom, pos, pos + svlen)
                
                f_out.write("\t".join(c))

        for f in [tmp_vcf, "chr_map.txt"]: 
            if os.path.exists(f): os.remove(f)
        print(f"Done: {s}")

if __name__ == "__main__":
    main()
