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
#
# LC_ALL=C: o Ansible espera o prompt de senha que ele mesmo passa em
# "sudo -p". O sudo só usa esse prompt quando o PAM pede a senha em inglês
# ("Password:"); num sistema em português o PAM diz "Senha:", o sudo mantém
# o prompt dele e o Ansible fica esperando para sempre ("Timed out waiting
# for become success or become password prompt"). Forçar o locale C resolve
# sem precisar mexer no sudoers.
LC_ALL=C ansible-pull -U "$REPO" --limit localhost --ask-become-pass
