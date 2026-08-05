# VM de Aula — configuração via Ansible (modelo pull)

Este repositório configura uma VM Ubuntu para as aulas: instala aplicações,
ajusta arquivos em `/etc` e mantém tudo versionado. O aluno roda **um comando**
para receber as atualizações que você publica aqui.

## O que é instalado

Ativo agora (veja `local.yml`):

- **PostgreSQL** (com config versionada em `/etc/postgresql`)

Prontas no repositório, mas **desativadas** (descomente a linha em
`local.yml` para ligar):

- **Apache Airflow** (venv dedicado em `/opt/airflow`, como serviço)
- **Python 3**, pip, venv, pipx e **Scrapy**
- **Lua 5.4** + `liblua5.4-dev` (role `common`, junto dos pacotes base)
- **Rustup** (toolchain stable, no home do aluno)
- **SWI-Prolog**
- **Clojure** CLI (+ JDK)

## Para o aluno

Primeira vez, numa VM limpa — instale o Ansible e aplique a configuração:

```bash
sudo apt update && sudo apt install -y ansible git
ansible-pull -U https://github.com/celsocrivelaro/senac-vm.git --limit localhost --ask-become-pass
```

Depois, sempre que houver atualização, é o mesmo comando (ou o atalho
`atualizar`, se você já criou o alias no `~/.bashrc`):

```bash
ansible-pull -U https://github.com/celsocrivelaro/senac-vm.git --limit localhost --ask-become-pass
```

Pede a senha do `sudo` (necessária para instalar pacotes e mexer em `/etc`).

> `--limit localhost` evita o aviso `Could not match supplied host pattern`:
> por padrão o `ansible-pull` limita a execução ao *hostname* da máquina, que
> não existe no inventário deste repositório.

## Para você (mantenedor)

1. Edite os arquivos e faça `git push`. Cada componente vive numa *role*:

```
local.yml              # lista as roles ativas (comente p/ desativar)
group_vars/all.yml     # versões e parâmetros centrais
roles/
  common/              # pacotes base + Lua
  postgresql/          # inclui templates de postgresql.conf e pg_hba.conf
  python/              # pip, venv, pipx, Scrapy
  airflow/             # venv + serviço systemd
  rust/  prolog/  clojure/
```

2. Para mudar uma config do Postgres, edite o template em
   `roles/postgresql/templates/`. Na próxima vez que o aluno rodar `update.sh`,
   o Ansible aplica a mudança e reinicia o Postgres **só se o arquivo mudou**.

## Testando antes de distribuir

Rode o playbook localmente sem clonar (a partir da pasta do repo):

```bash
sudo ansible-playbook local.yml
```

## Problemas comuns

**`Timed out waiting for become success or become password prompt`**
(e o sudo mostrando `Senha:`)

O Ansible passa o próprio prompt ao sudo (`sudo -p "[sudo via ansible,
key=...] password:"`) e espera exatamente por ele. O sudo só troca o prompt
do PAM pelo dele quando o PAM pede a senha em inglês (`Password:`); num
sistema em português o PAM diz `Senha:`, o sudo mantém esse texto e o
Ansible espera até dar timeout — a senha digitada nunca chega a ser enviada.

Solução usada aqui: rodar com `LC_ALL=C` (já está no `update.sh`).

Se ainda falhar, force o sudo a sempre usar o prompt do `-p`, uma única vez
por máquina:

```bash
echo 'Defaults passprompt_override' | sudo tee /etc/sudoers.d/ansible-prompt
sudo chmod 440 /etc/sudoers.d/ansible-prompt
```

**`Could not match supplied host pattern, ignoring: senac-bcc`**

Aviso inofensivo: o `ansible-pull` limita a execução ao hostname da máquina.
Use `--limit localhost` (já está no `update.sh`) para não aparecer.

## Observações honestas

- **Airflow**: a versão do Python em `group_vars/all.yml` (`airflow_python`)
  precisa bater com a do Ubuntu (26.04 → 3.14; 24.04 → 3.12; 22.04 → 3.10),
  senão o *constraints file* não é encontrado (erro 404 no pip). Atenção:
  Python 3.14 só é suportado a partir do **Airflow 3.2.0** — por isso este
  repositório usa o 3.3.0, e não mais o 2.10.4.
  No Airflow 3 a senha do admin **não** aparece no log; ela fica em
  `/opt/airflow/simple_auth_manager_passwords.json.generated`.
- **Postgres**: a `postgres_versao` deve corresponder ao que o Ubuntu instala
  (26.04 → 18; 24.04 → 16; 22.04 → 14). Se não bater, o pacote
  `postgresql-<versao>` não existe nos repositórios e o apt falha.
- **Rust e Clojure** instalam por ferramentas próprias (rustup / script oficial),
  não por apt — é o caminho recomendado por esses projetos.
- Teste tudo numa VM limpa antes da primeira aula; permissões de `sudo` são
  o ponto que mais costuma travar.
