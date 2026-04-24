# OpenAWSEM — GCC 14+ Compatible Fork

[![Python](https://img.shields.io/badge/Python-3.10-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/)
[![GCC](https://img.shields.io/badge/GCC-14%2B-A97BFF?style=flat-square&logo=c&logoColor=white)](https://gcc.gnu.org/)
[![Conda](https://img.shields.io/badge/Conda-Environment-44A833?style=flat-square&logo=anaconda&logoColor=white)](https://conda.io/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%2B-E95420?style=flat-square&logo=ubuntu&logoColor=white)](https://ubuntu.com/)

Fork do [npschafer/openawsem](https://github.com/npschafer/openawsem) com correções para compilar em **Ubuntu 24.04+ com GCC 14+**.

---

## Instalação Rápida

```bash
git clone https://github.com/Filippin20/openawsem.git
cd openawsem
bash patches/install_all.sh
```

Depois:
```bash
conda activate openawsem
source ~/.bashrc
python -c "import openawsem; print('OK')"
```

---

## O que o script faz automaticamente

1. Cria o ambiente Conda com Python 3.10
2. Instala **OpenMM 8**, **MDTraj**, **PDBFixer** e dependências
3. Clona o [Stride](https://github.com/heiniglab/stride) e aplica os patches de compatibilidade
4. Compila e instala o Stride em `~/.local/bin/stride`
5. Instala o OpenAWSEM via `pip install -e .`
6. Cria o arquivo `~/.awsem/config.ini`

---

## Por que este fork existe?

O **Stride** (analisador de estrutura secundária usado pelo OpenAWSEM) é um programa em C de 1995. O GCC 14 passou a rejeitar como erro uma declaração de ponteiro de função incompleta no arquivo `hydrbond.c`:

```c
/* ANTES — quebrado no GCC 14+ */
void (*HBOND_Energy)();

/* DEPOIS — corrigido */
void (*HBOND_Energy)(float *, float *, float *, float *, float *, COMMAND *, HBOND *);
```

Além disso, o `Makefile` do Stride precisa das flags:
```
-std=gnu89 -Wno-incompatible-pointer-types -Wno-implicit-function-declaration
```

O script `patches/install_all.sh` aplica tudo isso automaticamente.

> ⚠️ O warning `report.c: '%s' directive writing up to 1024 bytes` é inofensivo — apenas um aviso do compilador, não um erro.

---

## Requisitos

- Ubuntu 20.04+ (testado em 24.04)
- GCC instalado (`sudo apt install build-essential`)
- [Miniconda](https://docs.conda.io/en/latest/miniconda.html)
- Git

---

## Configuração manual do `~/.awsem/config.ini`

```ini
[Paths]
OPENAWSEM_LOCATION = /home/SEU_USUARIO/openawsem
STRIDE_BINARY      = /home/SEU_USUARIO/.local/bin/stride

[Simulation]
DEFAULT_PLATFORM    = CPU
DEFAULT_TEMPERATURE = 300
```

Ou use a variável de ambiente:
```bash
export OPENAWSEM_LOCATION="/home/SEU_USUARIO/openawsem"
```

---



**OpenAWSEM:**
> Lu et al. *PLOS Computational Biology*, 2021. DOI: [10.1371/journal.pcbi.1008308](https://doi.org/10.1371/journal.pcbi.1008308)

**Modelo AWSEM:**
> Davtyan et al. *J. Phys. Chem. B*, 2012. DOI: [10.1021/jp212541y](https://doi.org/10.1021/jp212541y)

**Stride:**
> Frishman & Argos. *Proteins*, 1995. DOI: [10.1002/prot.340230402](https://doi.org/10.1002/prot.340230402)

---

## Créditos

Código original por **Nicholas P. Schafer** e colaboradores — Rice University (Wolynes & Onuchic Labs).
Patches de compatibilidade GCC 14+ por **Filippin20**.
