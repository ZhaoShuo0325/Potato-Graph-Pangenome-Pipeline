import os

REF_GENOME = "/work1/data/reference/DM8.1_genome.fasta" # DMv8.1
CONFIG_DIR = os.path.expanduser("/work1/simulation/configs")

os.makedirs(CONFIG_DIR, exist_ok=True)

# 配置文件模板
config_template = """Project:
-----------------------------
Project name             = {project_name}
Reference sequence       = {ref_path}
Replace ambiguous nts(N) = Yes
Max threads              = 8
Seed                     = {seed}

Structural variation:
-----------------------------
VCF input                = 
Foreign sequences        = 

Deletions                = 8000
Length (bp)              = 50-150000

Insertions               = 8000
Length (bp)              = 50-100000

Tandem duplications      = 8000
Length (bp)              = 50-10000
Copies                   = 1-10

Inversions               = 200
Length (bp)              = 50-1000000

Complex substitutions    = 0
Length (bp)              = 30-1000

Inverted duplications    = 0
Length (bp)              = 150-10000

Heterozygosity           = 13%

Long Read simulation:
-----------------------------
Sequencing depth         = 0
Median length            = 15000
Length range             = 500-100000
Accuracy                 = 90%
Error profile            = error_profile_ONT.txt
"""

def generate_configs():
    for i in range(1, 2):
        hap_id = f"{i:02d}"
        project_name = f"Sim_{hap_id}"
        file_name = f"sim_hap{hap_id}_config.txt"
        file_path = os.path.join(CONFIG_DIR, file_name)
        
        content = config_template.format(
            project_name=project_name,
            ref_path=REF_GENOME,
            seed=i * 123  # 确保每个单倍型变异位置不同
        )
        
        with open(file_path, 'w') as f:
            f.write(content)
        
    print(f"已在 {CONFIG_DIR} 生成配置文件。")

if __name__ == "__main__":
    generate_configs()
