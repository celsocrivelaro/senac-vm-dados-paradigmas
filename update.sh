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
# SEM --ask-become-pass: o Ubuntu 26.04 usa o sudo-rs (reescrita em Rust),
# que não reescreve o prompt do PAM como o sudo original fazia. O Ansible
# depende disso para saber quando enviar a senha, então become com senha
# simplesmente não funciona aqui ("Timed out waiting for become success or
# become password prompt"). A solução é sudo sem senha para o aluno — veja
# "Problemas comuns" no README, é um comando, uma vez por máquina.
ansible-pull -U "$REPO" --limit localhost
