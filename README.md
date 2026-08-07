# VM de Aula — configuração via Ansible (modelo pull)

Este repositório configura uma VM Ubuntu para as aulas: instala aplicações,
ajusta arquivos em `/etc` e mantém tudo versionado. O aluno roda **um comando**
para receber as atualizações que você publica aqui.

## O que é instalado

Ativo agora (veja `local.yml`):

- **PostgreSQL** (com config versionada em `/etc/postgresql`) + uma role de
  login para o aluno
- **DBeaver Community** (repositório apt oficial) já com a conexão
  `PostgreSQL local (aula)` criada
- **VS Code** (repositório apt oficial da Microsoft) com as extensões de
  Python e SQL listadas em `group_vars/all.yml`

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
sudo ansible-pull -U https://github.com/celsocrivelaro/senac-vm.git --limit localhost
```

Depois, sempre que houver atualização, é só o último comando (ou o atalho
`atualizar`, se você já criou o alias no `~/.bashrc`):

```bash
sudo ansible-pull -U https://github.com/celsocrivelaro/senac-vm.git --limit localhost
```

O `sudo` na frente é proposital: no Ubuntu 26.04 o Ansible não consegue
enviar a senha do sudo por conta própria (veja "Problemas comuns"), então o
playbook roda já como root e é o sudo que pede a senha, no prompt dele.

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
  dbeaver/             # repo apt oficial + data-sources.json do aluno
  vscode/              # repo apt da Microsoft + extensões do aluno
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

É uma incompatibilidade conhecida (ansible#85837, sudo-rs#1461). A solução
adotada aqui é tirar o Ansible dessa conversa: rodar o playbook já como root,
com `sudo` na frente, e deixar o próprio sudo pedir a senha no prompt normal
dele. É o que o `update.sh` faz.

```bash
sudo ansible-pull -U https://github.com/celsocrivelaro/senac-vm.git --limit localhost
```

Como o playbook roda como root, `ansible_user_id` seria `root` — por isso
`aluno_usuario` em `group_vars/all.yml` vem de `SUDO_USER`, para que rustup,
pipx e afins caiam no home do aluno, e não em `/root`.

**Duas coisas que NÃO funcionam** (ambas testadas no 26.04):

- `Defaults passprompt_override` — opção do sudo original; o sudo-rs rejeita
  com `unknown setting`.
- Drop-in `NOPASSWD` em `/etc/sudoers.d/` — funciona em teoria, mas é
  arriscado: **um erro de sintaxe ali derruba o sudo da máquina inteira**, e o
  sudo-rs falha fechado. Se isso acontecer, o sudo não serve nem para
  desfazer; recupere com `pkexec rm /etc/sudoers.d/<arquivo>` ou pelo modo de
  recuperação do GRUB (root shell → `mount -o remount,rw /` → apague o
  arquivo). Se for mexer nesse diretório, use sempre `sudo visudo -f`, que
  valida antes de salvar.

Alternativa, se você quiser o `--ask-become-pass` de volta: reinstalar o sudo
original (`sudo apt install sudo`, que remove o sudo-rs). Funciona, mas foge
do padrão da distribuição — o Ubuntu 26.10 pretende deixar o sudo-rs como
único provedor.

**`E:Release file ... is not valid yet (invalid for another 1d 5h ...)`**

O relógio da VM está atrasado. O apt compara a data do arquivo `Release` com
a hora local; se a VM acha que ainda é anteontem, o índice do Ubuntu parece
"do futuro" e é recusado — nenhum pacote instala. Acontece com VM que ficou
suspensa ou voltou de snapshot.

O `local.yml` já tenta corrigir sozinho (`pre_tasks` liga o NTP e espera a
sincronização). Se mesmo assim falhar, acerte à mão:

```bash
sudo timedatectl set-ntp false
sudo timedatectl set-time "2026-08-07 14:30:00"
sudo timedatectl set-ntp true
timedatectl status     # confira "System clock synchronized: yes"
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
- **DBeaver**: a conexão vem pronta, mas **sem a senha salva** — o aluno digita
  na primeira vez (usuário e senha em `group_vars/all.yml`, padrão
  `estudante`/`estudante`) e marca "salvar" se quiser. O DBeaver guarda senha
  num arquivo cifrado, e gerar isso pelo Ansible quebraria a cada mudança de
  formato. O `data-sources.json` só é escrito se ainda não existir
  (`force: false`), então quem já tem conexões salvas não perde nada — e
  quem já abriu o DBeaver antes desta role não recebe a conexão pronta.
- **Rust e Clojure** instalam por ferramentas próprias (rustup / script oficial),
  não por apt — é o caminho recomendado por esses projetos.
- Teste tudo numa VM limpa antes da primeira aula; permissões de `sudo` são
  o ponto que mais costuma travar.
