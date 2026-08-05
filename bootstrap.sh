#!/usr/bin/env bash
# =====================================================================
# Passo ZERO — o aluno roda isto UMA vez, numa VM Ubuntu limpa.
# Instala o Ansible e aplica a configuração pela primeira vez.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/SEU_USUARIO/aula-vm/main/bootstrap.sh | bash
# (ou baixe o arquivo e rode: bash bootstrap.sh)
# =====================================================================
set -euo pipefail

REPO="https://github.com/SEU_USUARIO/aula-vm.git"

echo ">> Instalando o Ansible..."
sudo apt update
sudo apt install -y ansible git

echo ">> Aplicando a configuração pela primeira vez..."
# --ask-become-pass: pede a senha do sudo (necessária p/ instalar pacotes).
ansible-pull -U "$REPO" --ask-become-pass

echo ">> Pronto! Nas próximas vezes, rode:  ./update.sh"
