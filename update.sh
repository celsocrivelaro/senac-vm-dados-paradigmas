#!/usr/bin/env bash
# =====================================================================
# Comando do DIA A DIA — o aluno roda isto sempre que você avisar que
# há atualização no repositório. Puxa as mudanças e reaplica.
# =====================================================================
set -euo pipefail

REPO="https://github.com/celsocrivelaro/senac-vm.git"

# --limit localhost: o ansible-pull, por padrão, limita a execução ao
# hostname da máquina (ex.: "senac-bcc"), que não existe no inventário e
# gera o aviso "Could not match supplied host pattern".
ansible-pull -U "$REPO" --limit localhost --ask-become-pass
