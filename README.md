# VM de Aula — configuração via Ansible (modelo pull)

Este repositório configura uma VM para as aulas: instala aplicações, ajusta
arquivos em `/etc` e mantém tudo versionado. O aluno roda **um comando** para
receber as atualizações que você publica aqui.

Testado no **Ubuntu 26.04** (Lubuntu) e no **Debian 13** (trixie). As versões
que mudam entre as duas — PostgreSQL e Python — são descobertas em tempo de
execução, então não há variável para editar ao trocar de distribuição.

## O que é instalado

Ativo agora (veja `local.yml`):

- **PostgreSQL** (a versão empacotada pela distribuição) com a config
  versionada em `/etc/postgresql` e a role de login do aluno já criada
  (`estudante`/`estudante`, ajustável em `group_vars/all.yml`)
- **MongoDB Community** 8.0 (tarball oficial em `/opt/mongodb`,
  como serviço systemd) em `mongodb://localhost:27017`, sem autenticação e
  escutando só o localhost, mais o **mongosh** no PATH
- **MongoDB Compass** (`.deb` oficial) — a tela de conexão já abre sugerindo
  `mongodb://localhost:27017`, que é exatamente o banco local. **Só em amd64**:
  a MongoDB não publica build arm64 do Compass para Linux
- **DBeaver Community** (repositório apt oficial) já com a conexão
  `PostgreSQL local (aula)` criada
- **VS Code** (repositório apt oficial da Microsoft) com as extensões de
  Python e SQL listadas em `group_vars/all.yml`
- **Docker Engine** + CLI, buildx e Compose v2 (repositório apt oficial da
  Docker), com o aluno já no grupo `docker`
- **Python**: os pacotes listados em `python_pacotes` (`python3-pip` e
  `python3-venv`). `pipx` e `Scrapy` são extras da mesma role, ligados por
  `python_instalar_pipx` e `python_instalar_scrapy`
- **Metabase** em <http://localhost:4444> (JAR + systemd, Java 25), login
  `estudante@sp.senac.br`/`senac`, já com o Postgres local cadastrado como
  **Postgres da aula** — o aluno abre a página e sai consultando

> O assistente da primeira tela do Metabase não aparece: a role faz o mesmo
> caminho pela API (`/api/setup` e `/api/database`) na primeira execução, com
> os valores `metabase_admin_*` de `group_vars/all.yml`. Numa VM onde alguém
> já concluiu o assistente à mão, o `setup-token` foi consumido na criação do
> primeiro usuário e não volta: a role para com uma mensagem pedindo que você
> aponte `metabase_admin_email`/`metabase_admin_senha` para a conta existente
> ou repita o comando com `-e metabase_recriar_banco_interno=true`, que apaga
> o banco interno (dashboards e perguntas salvas vão junto).

Prontas no repositório, mas **desativadas** (descomente a linha em
`local.yml` para ligar):

- **Apache Airflow 3** (venv dedicado em `/opt/airflow`, como serviço systemd),
  em <http://localhost:9876>, login `senac`/`senac` — sem os DAGs de exemplo e
  com uma única conexão, `postgres_aula`, apontando para o Postgres local
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
playbook roda já como root e é o sudo que pede a senha, no prompt dele. No
Debian 13 o `--ask-become-pass` funcionaria, mas rodar com `sudo` também
funciona — vale o mesmo comando nas duas distribuições.

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
  docker/              # repo apt da Docker (URL e suite vindas dos fatos)
  vscode/              # repo apt da Microsoft + extensões do aluno
  python/              # pip, venv, pipx, Scrapy
  mongodb/             # tarball + systemd, mongosh e o .deb do Compass
  metabase/            # JAR + serviço systemd + setup pela API
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

> Isto é **específico do Ubuntu 26.04**. O Debian 13 continua com o sudo
> original (GNU sudo 1.9.16) — o `sudo-rs` existe no repositório, mas não é o
> provedor padrão —, então nada desta seção se aplica lá.

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
  desfazer; recupere com `pkexec rm /etc/sudoers.d/<arquivo>` (precisa de um
  agente do polkit no ambiente gráfico) ou pelo modo de recuperação do GRUB
  (root shell → `mount -o remount,rw /` → apague o arquivo). Se for mexer
  nesse diretório, use sempre `sudo visudo -f`, que valida antes de salvar.

Alternativa, se você quiser o `--ask-become-pass` de volta: reinstalar o sudo
original (`sudo apt install sudo`, que remove o sudo-rs). Funciona, mas foge
do padrão da distribuição — o Ubuntu 26.10 pretende deixar o sudo-rs como
único provedor.

**`E:Release file ... is not valid yet (invalid for another 1d 5h ...)`**

O relógio da VM está atrasado. O apt compara a data do arquivo `Release` com
a hora local; se a VM acha que ainda é anteontem, o índice da distribuição
parece "do futuro" e é recusado — nenhum pacote instala. Acontece com VM que
ficou suspensa ou voltou de snapshot.

O playbook não mexe no relógio; acerte antes de rodar:

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

- **Airflow**: `airflow_python` é derivado do Python do sistema, não escrito à
  mão — a role confere se o Airflow publica *constraints* para aquela versão e
  falha em segundos com mensagem clara se não publicar, em vez de estourar um
  404 no meio de um `pip` de vários minutos. Atenção: Python 3.14 só é
  suportado a partir do **Airflow 3.2.0** — por isso este repositório usa o
  3.3.0, e não mais o 2.10.4.
  O login da interface web é fixado pelo repositório (`airflow_usuario` e
  `airflow_senha`, padrão `senac`/`senac`), gravado em
  `/opt/airflow/simple_auth_manager_passwords.json`. Sem isso o Airflow 3
  sortearia uma senha diferente em cada VM e nem a mostraria no log.
- **Postgres**: a role instala o metapacote `postgresql` e **descobre** a versão
  lendo o diretório criado em `/etc/postgresql`, em vez de ter o número no
  `group_vars`. É o que permite o mesmo repositório servir Ubuntu 26.04 (18) e
  Debian 13 (17) sem editar nada. Para forçar: `-e postgres_versao=17`.
- **MongoDB**: única role que não usa repositório apt, por falta de opção. A
  MongoDB ainda não publica o servidor para Ubuntu 26.04 nem para Debian 13
  (os repositórios existem, mas só trazem `mongodb-database-tools` e o
  `mongosh`), e nenhuma das duas distribuições empacota o MongoDB desde a
  mudança de licença para SSPL. Então vem do tarball oficial em `/opt/mongodb`,
  com unit própria — o mesmo padrão da role `metabase`. Usamos o build de
  Ubuntu 24.04 nas duas distribuições: ele só precisa de `libssl.so.3` e
  `libcurl.so.4` em tempo de execução, e é o único alvo com `aarch64` (o de
  Debian 12 sai só em x86_64). Quando a MongoDB publicar para `resolute` e
  `trixie`, dá para simplificar a role para um `apt` comum — confira em
  <https://repo.mongodb.org/apt/ubuntu/dists/>.
- **MongoDB Compass**: só existe `.deb` **amd64**; não há build arm64 para
  Linux. Numa VM ARM a role avisa e segue, sem derrubar o playbook — o aluno
  usa o `mongosh`, que tem as duas arquiteturas.
- **Docker**: entrar no grupo `docker` só vale a partir do próximo login — na
  sessão atual, `docker ps` ainda vai pedir sudo. `newgrp docker` resolve sem
  reiniciar. Vale saber que pertencer a esse grupo equivale a ter root na
  máquina (dá para montar o disco do host num container); numa VM de aula onde
  o aluno já tem sudo completo, não muda nada na prática.
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
