#!/bin/bash
# One-time install of R packages + CmdStan on Engaging.
# Submit from the repo root on the cluster:
#   sbatch analysis/models/cluster/install_packages.slurm
#SBATCH --job-name=paper-b-install
#SBATCH --partition=mit_normal
#SBATCH --account=mit_general
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --output=analysis/models/cluster/logs/install_%j.out

set -eo pipefail
# Same toolchain as the fitting jobs (see env.sh).
source analysis/models/cluster/env.sh
Rscript analysis/models/cluster/install_packages.R
