#!/usr/bin/env bash
# =====================================================================
# Comando do DIA A DIA — o aluno roda isto sempre que você avisar que
# há atualização no repositório. Puxa as mudanças e reaplica.
# =====================================================================
set -euo pipefail

REPO="https://github.com/SEU_USUARIO/aula-vm.git"

ansible-pull -U "$REPO" --ask-become-pass
