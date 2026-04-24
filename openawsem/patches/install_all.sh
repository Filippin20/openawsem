#!/usr/bin/env bash
# =============================================================================
# install_all.sh — OpenAWSEM Modern GCC Fork
# Instalação automática completa para Ubuntu 24.04+ com GCC 14+
# =============================================================================
# Uso: bash patches/install_all.sh
# =============================================================================

set -euo pipefail

# ── Cores para output ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_section() { echo -e "\n${BLUE}══════════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}══════════════════════════════════════════${NC}"; }

# ── Configurações ─────────────────────────────────────────────────────────
CONDA_ENV_NAME="openawsem"
PYTHON_VERSION="3.10"
STRIDE_REPO="https://github.com/heiniglab/stride.git"
STRIDE_BUILD_DIR="/tmp/stride_build_$$"
STRIDE_INSTALL_DIR="${HOME}/.local/bin"
OPENAWSEM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWSEM_CONFIG_DIR="${HOME}/.awsem"
AWSEM_CONFIG_FILE="${AWSEM_CONFIG_DIR}/config.ini"
SHELL_RC="${HOME}/.bashrc"

# Detectar zsh
if [[ "${SHELL}" == *"zsh"* ]]; then
    SHELL_RC="${HOME}/.zshrc"
    log_info "Shell detectado: zsh → usando ${SHELL_RC}"
fi

# ── Verificar dependências do sistema ────────────────────────────────────
log_section "1/7 — Verificando dependências do sistema"

command -v gcc >/dev/null 2>&1 || log_error "GCC não encontrado. Execute: sudo apt-get install build-essential"
command -v make >/dev/null 2>&1 || log_error "make não encontrado. Execute: sudo apt-get install build-essential"
command -v git >/dev/null 2>&1 || log_error "git não encontrado. Execute: sudo apt-get install git"
command -v conda >/dev/null 2>&1 || log_error "Conda não encontrado. Instale o Miniconda: https://docs.conda.io/en/latest/miniconda.html"

GCC_VERSION=$(gcc -dumpversion | cut -d. -f1)
log_info "GCC versão detectada: ${GCC_VERSION}"
if [[ ${GCC_VERSION} -ge 13 ]]; then
    log_warn "GCC ${GCC_VERSION} detectado — patches de compatibilidade serão aplicados automaticamente."
fi

log_ok "Todas as dependências do sistema encontradas."

# ── Criar ambiente Conda ──────────────────────────────────────────────────
log_section "2/7 — Configurando ambiente Conda: ${CONDA_ENV_NAME}"

# Inicializar conda no script
eval "$(conda shell.bash hook 2>/dev/null || true)"

if conda env list | grep -q "^${CONDA_ENV_NAME} "; then
    log_warn "Ambiente '${CONDA_ENV_NAME}' já existe. Pulando criação."
else
    log_info "Criando ambiente Conda com Python ${PYTHON_VERSION}..."
    conda create -n "${CONDA_ENV_NAME}" python="${PYTHON_VERSION}" -y
    log_ok "Ambiente Conda criado."
fi

log_info "Ativando ambiente ${CONDA_ENV_NAME}..."
conda activate "${CONDA_ENV_NAME}"

# ── Instalar dependências Python ──────────────────────────────────────────
log_section "3/7 — Instalando dependências Python"

log_info "Instalando OpenMM, MDTraj, PDBFixer via conda-forge..."
conda install -c conda-forge \
    "openmm>=8.0" \
    mdtraj \
    pdbfixer \
    numpy \
    pandas \
    scipy \
    matplotlib \
    -y

log_info "Instalando dependências pip adicionais..."
pip install --quiet \
    "biopython==1.79" \
    networkx \
    pytest

log_ok "Dependências Python instaladas."

# ── Clonar e compilar o Stride ───────────────────────────────────────────
log_section "4/7 — Clonando e compilando Stride"

log_info "Clonando Stride em ${STRIDE_BUILD_DIR}..."
git clone --depth=1 "${STRIDE_REPO}" "${STRIDE_BUILD_DIR}"

log_info "Aplicando patch 1: corrigindo hydrbond.c (declaração do ponteiro HBOND_Energy)..."
HYDRBOND="${STRIDE_BUILD_DIR}/hydrbond.c"

if [[ -f "${HYDRBOND}" ]]; then
    if grep -q "void (\*HBOND_Energy)()" "${HYDRBOND}"; then
        log_info "Declaração incompleta detectada — corrigindo..."
        sed -i \
            's/void (\*HBOND_Energy)()/void (*HBOND_Energy)(float *, float *, float *, float *, float *, COMMAND *, HBOND *)/g' \
            "${HYDRBOND}"
        log_ok "Patch 1 aplicado: hydrbond.c corrigido."
    else
        log_warn "Declaração HBOND_Energy já está correta — pulando patch."
    fi
else
    log_error "hydrbond.c não encontrado em ${STRIDE_BUILD_DIR}"
fi

log_info "Aplicando patch 2: corrigindo Makefile (flags -std=gnu89 e -Wno-incompatible-pointer-types)..."
MAKEFILE="${STRIDE_BUILD_DIR}/Makefile"
if [[ -f "${MAKEFILE}" ]]; then
    # Substituir linha CFLAGS existente
    if grep -q "^CFLAGS" "${MAKEFILE}"; then
        sed -i \
            's|^CFLAGS\s*=.*|CFLAGS = -std=gnu89 -Wno-incompatible-pointer-types -Wno-implicit-function-declaration -Wno-error|g' \
            "${MAKEFILE}"
    else
        # Inserir CFLAGS antes da primeira linha CC= ou CFLAGS
        sed -i \
            '/^CC\s*=/i CFLAGS = -std=gnu89 -Wno-incompatible-pointer-types -Wno-implicit-function-declaration -Wno-error' \
            "${MAKEFILE}"
    fi
    log_ok "Patch 2 aplicado: Makefile corrigido."
else
    log_warn "Makefile não encontrado. Compilando com CFLAGS inline..."
fi

log_info "Compilando Stride..."
cd "${STRIDE_BUILD_DIR}"
if [[ -f Makefile ]]; then
    make -j"$(nproc)" 2>&1
else
    # Compilação manual como fallback
    CFLAGS="-std=gnu89 -Wno-incompatible-pointer-types -Wno-implicit-function-declaration -Wno-error"
    gcc ${CFLAGS} -o stride src/*.c -lm 2>&1 || \
    gcc ${CFLAGS} -o stride *.c -lm 2>&1
fi

# Encontrar e instalar o binário
STRIDE_BIN=$(find "${STRIDE_BUILD_DIR}" -maxdepth 2 -name "stride" -type f | head -n 1)
if [[ -z "${STRIDE_BIN}" ]]; then
    log_error "Binário 'stride' não encontrado após compilação."
fi

mkdir -p "${STRIDE_INSTALL_DIR}"
cp "${STRIDE_BIN}" "${STRIDE_INSTALL_DIR}/stride"
chmod +x "${STRIDE_INSTALL_DIR}/stride"
log_ok "Stride compilado e instalado em ${STRIDE_INSTALL_DIR}/stride"

# Limpar build temporário
rm -rf "${STRIDE_BUILD_DIR}"
cd "${OPENAWSEM_DIR}"

# ── Instalar OpenAWSEM ────────────────────────────────────────────────────
log_section "5/7 — Instalando OpenAWSEM"

log_info "Instalando OpenAWSEM em modo editável (pip install -e .)..."
pip install -e . --quiet
log_ok "OpenAWSEM instalado."

# ── Configurar variáveis de ambiente ─────────────────────────────────────
log_section "6/7 — Configurando variáveis de ambiente"

# Remover entradas antigas para evitar duplicatas
sed -i '/OPENAWSEM_LOCATION/d' "${SHELL_RC}" 2>/dev/null || true
sed -i '/# OpenAWSEM PATH/d' "${SHELL_RC}" 2>/dev/null || true

# Adicionar novas entradas
cat >> "${SHELL_RC}" << ENVEOF

# OpenAWSEM PATH
export OPENAWSEM_LOCATION="${OPENAWSEM_DIR}"
export PATH="${STRIDE_INSTALL_DIR}:\${PATH}"
ENVEOF

log_ok "Variáveis de ambiente adicionadas em ${SHELL_RC}"

# ── Criar config.ini ──────────────────────────────────────────────────────
log_section "7/7 — Criando ${AWSEM_CONFIG_FILE}"

mkdir -p "${AWSEM_CONFIG_DIR}"

cat > "${AWSEM_CONFIG_FILE}" << CONFIGEOF
[Data Paths]
blast = /home/USER/data/database/cullpdb_pc80_res3.0_R1.0_d160504_chains29712
gro = /home/USER/data/Gros
pdb = /home/USER/data/PDBs
index = /home/USER/data/Indices
pdbfail = /home/USER/data/notExistPDBsList
pdbseqres = /home/USER/data/pdb_seqres.txt
topology = /home/USER/topology
CONFIGEOF

log_ok "Arquivo config.ini criado em ${AWSEM_CONFIG_FILE}"

# ── Resumo Final ──────────────────────────────────────────────────────────
echo ""
log_section "✅ Instalação Concluída!"
echo ""
echo -e "  ${GREEN}Ambiente Conda:${NC}        ${CONDA_ENV_NAME}"
echo -e "  ${GREEN}OpenAWSEM:${NC}             ${OPENAWSEM_DIR}"
echo -e "  ${GREEN}Stride:${NC}                ${STRIDE_INSTALL_DIR}/stride"
echo -e "  ${GREEN}Config:${NC}                ${AWSEM_CONFIG_FILE}"
echo -e "  ${GREEN}Shell RC:${NC}              ${SHELL_RC}"
echo ""
echo -e "${YELLOW}PRÓXIMOS PASSOS:${NC}"
echo -e "  1. Recarregue o shell:  ${CYAN}source ${SHELL_RC}${NC}"
echo -e "  2. Ative o ambiente:    ${CYAN}conda activate ${CONDA_ENV_NAME}${NC}"
echo -e "  3. Teste:               ${CYAN}python -c \"import openawsem; print('OK')\"${NC}"
echo -e "  4. Verifique stride:    ${CYAN}stride --help${NC}"
echo ""
