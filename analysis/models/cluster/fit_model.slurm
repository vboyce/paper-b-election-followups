#!/bin/bash
# Fit one model on Engaging. Submit from the repo root on the cluster:
#   sbatch analysis/models/cluster/fit_model.slurm <spec> <study> [set]
#   sbatch analysis/models/cluster/fit_model.slurm maze_pronoun_1 2024
#   sbatch analysis/models/cluster/fit_model.slurm spr_pronoun_1 2020 high_attention
#SBATCH --job-name=paper-b-fit
#SBATCH --partition=mit_normal
#SBATCH --account=mit_general
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --output=analysis/models/cluster/logs/fit_%j.out

set -eo pipefail
if [ "$#" -lt 2 ]; then
  echo "Usage: sbatch analysis/models/cluster/fit_model.slurm <spec> <study> [set]" >&2
  exit 1
fi
# Same toolchain the packages were installed with (see env.sh).
source analysis/models/cluster/env.sh
echo "Fitting: $*"
Rscript analysis/models/fit_model.R "$@"
