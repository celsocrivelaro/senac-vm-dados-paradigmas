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

Primeira vez, numa VM limpa — instale o Ansible, libere o sudo sem senha
(obrigatório no 26.04, veja "Problemas comuns") e aplique a configuração:

```bash
sudo apt update && sudo apt install -y ansible git
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/aula-ansible
sudo chmod 440 /etc/sudoers.d/aula-ansible
ansible-pull -U https://github.com/celsocrivelaro/senac-vm.git --limit localhost
```

Depois, sempre que houver atualização, é só o último comando (ou o atalho
`atualizar`, se você já criou o alias no `~/.bashrc`):

```bash
ansible-pull -U https://github.com/celsocrivelaro/senac-vm.git --limit localhost
```

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
(e o sudo mostrando `[sudo: [sudo via ansible, key=...] password:] Senha:`)

O Ubuntu 26.04 substituiu o sudo original pelo **sudo-rs** (reescrita em
Rust). O sudo original capturava o prompt de senha do PAM e o reescrevia com
o que o Ansible passa em `-p`; o Ansible depende exatamente disso para saber
o momento de enviar a senha. O sudo-rs não faz essa reescrita — ele imprime
o prompt do Ansible entre colchetes e repassa a autenticação ao PAM. Ou seja:
**become com senha não funciona no 26.04**, independente de idioma.

É uma incompatibilidade conhecida (ansible#85837, sudo-rs#1461). A solução é
não usar senha no become — sudo sem senha para o aluno, **um comando, uma vez
por máquina**:

```bash
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/aula-ansible
sudo chmod 440 /etc/sudoers.d/aula-ansible
```

Depois disso o `update.sh` roda sem pedir senha nenhuma. Numa VM de aula isso
é aceitável: o aluno já tem sudo completo de qualquer forma.

> Não use `Defaults passprompt_override`: essa opção é do sudo original e o
> sudo-rs a rejeita com `unknown setting`.

Alternativa, se você preferir manter a senha: reinstalar o sudo original
(`sudo apt install sudo`, que remove o sudo-rs). Funciona, mas foge do padrão
da distribuição — o Ubuntu 26.10 pretende deixar o sudo-rs como único
provedor.

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
