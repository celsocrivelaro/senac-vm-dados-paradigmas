# VM de Aula — configuração via Ansible (modelo pull)

Este repositório configura uma VM Ubuntu para as aulas: instala aplicações,
ajusta arquivos em `/etc` e mantém tudo versionado. O aluno roda **um comando**
para receber as atualizações que você publica aqui.

## O que é instalado

- **PostgreSQL** (com config versionada em `/etc/postgresql`)
- **Apache Airflow** (venv dedicado em `/opt/airflow`, como serviço)
- **Python 3**, pip, venv, pipx e **Scrapy**
- **Lua 5.4** + `liblua5.4-dev`
- **Rustup** (toolchain stable, no home do aluno)
- **SWI-Prolog**
- **Clojure** CLI (+ JDK)

## Para o aluno

Primeira vez, numa VM limpa:

```bash
curl -fsSL https://raw.githubusercontent.com/SEU_USUARIO/aula-vm/main/bootstrap.sh | bash
```

Depois, sempre que houver atualização:

```bash
./update.sh
```

Ambos pedem a senha do `sudo` (necessária para instalar pacotes e mexer em `/etc`).

## Para você (mantenedor)

1. Substitua `SEU_USUARIO` por seu usuário do GitHub em `bootstrap.sh`,
   `update.sh` e neste README.
2. Edite os arquivos e faça `git push`. Cada componente vive numa *role*:

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

3. Para mudar uma config do Postgres, edite o template em
   `roles/postgresql/templates/`. Na próxima vez que o aluno rodar `update.sh`,
   o Ansible aplica a mudança e reinicia o Postgres **só se o arquivo mudou**.

## Testando antes de distribuir

Rode o playbook localmente sem clonar (a partir da pasta do repo):

```bash
sudo ansible-playbook local.yml
```

## Observações honestas

- **Airflow**: a versão do Python em `group_vars/all.yml` (`airflow_python`)
  precisa bater com a do Ubuntu (24.04 → 3.12; 22.04 → 3.10), senão o
  *constraints file* não é encontrado. A senha do admin aparece no log:
  `journalctl -u airflow`.
- **Postgres**: a `postgres_versao` deve corresponder ao que o Ubuntu instala
  (24.04 → 16). Se não bater, o caminho `/etc/postgresql/<versao>/main` não existe.
- **Rust e Clojure** instalam por ferramentas próprias (rustup / script oficial),
  não por apt — é o caminho recomendado por esses projetos.
- Teste tudo numa VM limpa antes da primeira aula; permissões de `sudo` são
  o ponto que mais costuma travar.
