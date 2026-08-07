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
# "sudo ansible-pull" em vez de "--ask-become-pass": o Ubuntu 26.04 usa o
# sudo-rs, que não reescreve o prompt do PAM como o sudo original fazia. O
# Ansible depende disso para saber quando enviar a senha, então become com
# senha não funciona ("Timed out waiting for become success or become
# password prompt"). Rodando o playbook já como root, quem pede a senha é o
# próprio sudo, no prompt normal dele — o Ansible não entra nessa conversa.
# Assim não é preciso mexer no /etc/sudoers.d.
sudo ansible-pull -U "$REPO" --limit localhost
