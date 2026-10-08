# Environment for every paper-b R job on Engaging (sourced by the .slurm
# scripts), so installing and fitting always use the same toolchain.
#
# Uses the native Spack R (r/4.4.0), built with gcc 12.2.0. NOT the R/4.x.x
# modules: those run R inside an Apptainer container whose C++ runtime
# (gcc 8.5) can't load code compiled with the host's gcc 12 (RcppParallel's
# TBB failed with "CXXABI_1.3.13 not found", 2026-10-07).
#
# R_LIBS_USER is left at the module's default per-user library
# (~/R/x86_64-pc-linux-gnu-library/4.4); setting it to an empty directory
# would hide the installed packages.

module load gcc/12.2.0
module load r/4.4.0
# cmake: needed to build RcppParallel (a brms dependency).
module load cmake/3.27.9

echo "R: $(command -v R) ($(R --version | head -1))"
echo "g++: $(command -v g++) ($(g++ --version | head -1))"
case "$(command -v R)" in
  /orcd/software/core/001/spack/pkg/r/4.4.0/*) ;;
  *) echo "ERROR: expected the native Spack r/4.4.0, got $(command -v R)" >&2; exit 1 ;;
esac
