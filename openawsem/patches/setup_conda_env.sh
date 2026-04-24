#!/usr/bin/env bash
# =============================================================================
# setup_conda_env.sh — Configura apenas o ambiente Conda para OpenAWSEM
# =============================================================================
# Uso: bash patches/setup_conda_env.sh [nome_do_ambiente]
# =============================================================================

set -euo pipefail

ENV_NAME="${1:-openawsem}"
PYTHON_VERSION="3.10"

echo "[INFO] Criando ambiente Conda: ${ENV_NAME} (Python ${PYTHON_VERSION})"

eval "$(conda shell.bash hook 2>/dev/null || true)"

conda create -n "${ENV_NAME}" python="${PYTHON_VERSION}" -y

conda activate "${ENV_NAME}"

echo "[INFO] Instalando dependências via conda-forge..."
conda install -c conda-forge \
    "openmm>=8.0" \
    mdtraj \
    pdbfixer \
    numpy \
    pandas \
    scipy \
    matplotlib \
    -y

echo "[INFO] Instalando dependências pip..."
pip install --quiet biopython networkx pytest

echo ""
echo "[OK] Ambiente '${ENV_NAME}' pronto!"
echo "     Ative com: conda activate ${ENV_NAME}"
