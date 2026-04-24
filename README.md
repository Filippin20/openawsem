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

### PSIBLAST

Instale via bioconda:

```bash
conda install -c conda-forge -c bioconda blast
```

Ou baixe diretamente:

```bash
wget https://ftp.ncbi.nlm.nih.gov/blast/executables/LATEST/$(curl -s "https://ftp.ncbi.nlm.nih.gov/blast/executables/LATEST/" | grep -o 'ncbi-blast-[0-9.]*+-x64-linux.tar.gz' | head -n 1)
tar -xvzf ncbi-*.tar.gz
cd ncbi*/bin
echo 'export PATH=$PATH:'`pwd` >> ~/.bashrc
```

### PDB_SEQRES

```bash
wget https://files.rcsb.org/pub/pdb/derived_data/pdb_seqres.txt
OPENAWSEM_LOCATION=$(python -c "import openawsem; print(openawsem.__location__)")
cp pdb_seqres.txt $OPENAWSEM_LOCATION/data
```

### Predict_Property

Para predição de estrutura secundária a partir de arquivo fasta, instale em:  
https://github.com/realbigws/Predict_Property

Após a instalação, adicione ao PATH:
```bash
export PATH=$PATH:/caminho/para/Predict_Property/
```

---

## Configuração

O OpenAWSEM permite configurar os caminhos de armazenamento de dados:

1. Crie o diretório `.awsem` na sua pasta home (No caso, já está criado!)
2. Dentro de `.awsem`, crie o arquivo `config.ini` com os caminhos dos dados

Os caminhos padrão apontam para o diretório `data/` dentro do módulo OpenAWSEM.  
O script `patches/install_all.sh` cria este arquivo automaticamente.

Exemplo de `config.ini`:

```ini
[Data Paths]
blast    = /home/USER/data/database/cullpdb_pc80_res3.0_R1.0_d160504_chains29712
gro      = /home/USER/data/Gros
pdb      = /home/USER/data/PDBs
index    = /home/USER/data/Indices
pdbfail  = /home/USER/data/notExistPDBsList
pdbseqres = /home/USER/data/pdb_seqres.txt
topology = /home/USER/topology
```

---

## Exemplo

Simulação do domínio amino-terminal do repressor do Fago 434 (`1r69`)

**1. Ativar o ambiente:**
```bash
conda activate openawsem
```

**2. Criar a pasta de simulação:**  
O comando `awsem_create` baixa automaticamente o PDB correspondente.
```bash
awsem_create 1r69 --frag
```
Ou, se já tiver o arquivo `1r69.pdb`:
```bash
awsem_create 1r69.pdb --frag
```

**3. Modificar o `forces_setup.py`:**  
O `forces_setup.py` define quais termos de força são incluídos na simulação.  
Para ativar o fragment memory term, substitua a linha do single memory:
```python
# DE:
templateTerms.fragment_memory_term(oa, frag_file_list_file="./single_frags.mem", npy_frag_table="./single_frags.npy", UseSavedFragTable=False),

# PARA:
templateTerms.fragment_memory_term(oa, frag_file_list_file="./frags.mem", npy_frag_table="./frags.npy", UseSavedFragTable=False),
```

**4. Rodar a simulação:**  
Simulações reais tipicamente usam de 5 a 30 milhões de steps.
```bash
awsem_run 1r69 --platform CPU --steps 1e5 --tempStart 800 --tempEnd 200 -f forces_setup.py
```

**5. Calcular Energia e Q:**
```bash
awsem_analyze 1r69 > info.dat
```

**6. Scripts locais (opcional):**
```bash
./mm_run.py 1r69 --platform CPU --steps 1e5 --tempStart 800 --tempEnd 200 -f forces_setup.py
./mm_analyze.py 1r69 > energy.dat
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
