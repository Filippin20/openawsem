#!/usr/bin/env bash
# =============================================================================
# patch_stride.sh — Aplica apenas os patches de compatibilidade no Stride
# Para usar quando você já tem o Stride clonado localmente.
# =============================================================================
# Uso: bash patches/patch_stride.sh /caminho/para/stride
# =============================================================================

set -euo pipefail

STRIDE_DIR="${1:-/tmp/stride}"

if [[ ! -d "${STRIDE_DIR}" ]]; then
    echo "[ERROR] Diretório não encontrado: ${STRIDE_DIR}"
    echo "Uso: bash patch_stride.sh /caminho/para/stride"
    exit 1
fi

echo "[INFO] Aplicando patches em: ${STRIDE_DIR}"

# ── Patch 1: stride.h ─────────────────────────────────────────────────────
# Encontrar stride.h (pode estar em src/ ou na raiz)
STRIDE_H=$(find "${STRIDE_DIR}" -name "stride.h" | head -n 1)

if [[ -n "${STRIDE_H}" ]]; then
    echo "[INFO] Patching: ${STRIDE_H}"
    # Backup
    cp "${STRIDE_H}" "${STRIDE_H}.bak"
    # Aplicar correção da assinatura do ponteiro de função HBOND_Energy
    # ANTES: void (*HBOND_Energy)();
    # DEPOIS: void (*HBOND_Energy)(float, float, float *, float *, float *, float *, float *);
    sed -i \
        's/void (\*HBOND_Energy)()/void (*HBOND_Energy)(float, float, float *, float *, float *, float *, float *)/g' \
        "${STRIDE_H}"
    echo "[OK]   stride.h corrigido (backup em ${STRIDE_H}.bak)"
else
    echo "[WARN] stride.h não encontrado em ${STRIDE_DIR}"
fi

# ── Patch 2: Makefile ─────────────────────────────────────────────────────
MAKEFILE="${STRIDE_DIR}/Makefile"

if [[ -f "${MAKEFILE}" ]]; then
    echo "[INFO] Patching: ${MAKEFILE}"
    cp "${MAKEFILE}" "${MAKEFILE}.bak"

    if grep -q "^CFLAGS" "${MAKEFILE}"; then
        # Substituir linha CFLAGS existente
        sed -i \
            's|^CFLAGS\s*=.*|CFLAGS = -std=gnu89 -Wno-incompatible-pointer-types -Wno-implicit-function-declaration -Wno-error|g' \
            "${MAKEFILE}"
        echo "[OK]   CFLAGS substituído no Makefile"
    else
        # Inserir CFLAGS antes da primeira ocorrência de CC=
        sed -i \
            '/^CC\s*=/i CFLAGS = -std=gnu89 -Wno-incompatible-pointer-types -Wno-implicit-function-declaration -Wno-error' \
            "${MAKEFILE}"
        echo "[OK]   CFLAGS inserido no Makefile (antes de CC=)"
    fi
    echo "[OK]   Makefile corrigido (backup em ${MAKEFILE}.bak)"
else
    echo "[WARN] Makefile não encontrado em ${STRIDE_DIR}"
fi

echo ""
echo "[OK] Patches aplicados. Compile com: cd ${STRIDE_DIR} && make -j\$(nproc)"
