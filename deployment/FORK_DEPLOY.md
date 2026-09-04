# Deploy do fork Allvasc/chatwoot

Este fork adiciona customizações MIT ao Chatwoot self-hosted e roda em VPS via
**EasyPanel**. Este documento é a fonte de verdade para deploy — leia antes de
mexer em `config/features.yml`, `db/migrate/`, `docker/entrypoints/` ou nos
workflows.

## Arquitetura

```
branch `deploy`  ──push──▶  GitHub Actions
                              ├─ fork-guardrails.yml   (bloqueia se violar as regras abaixo)
                              ├─ fork-spec.yml         (RSpec das customizações; roda, ainda não bloqueia)
                              └─ build-image.yml       (só roda se guardrails passar)
                                    └─ push ▶ ghcr.io/allvasc/chatwoot:latest
                                                          │
                                              EasyPanel (VPS) ── pull ──▶ serviços
                                                chatwoot (web) · chatwoot-sidekiq
                                                chatwoot-db (Postgres) · chatwoot-redis
```

- **Branch de produção:** `deploy` (criada da tag `v4.17.1`). `upstream` = `chatwoot/chatwoot`.
- **Imagem:** `ghcr.io/allvasc/chatwoot:latest` (e `:<sha>`). Buildada só pelo CI — nunca `docker build`/`push` na mão.
- **1 commit por mudança.** Conventional Commits. Sem mencionar Claude/IA (ver AGENTS.md).

## Regras que NÃO podem ser violadas

Cada uma já causou incidente em produção. O CI (`fork-guardrails`) barra todas.

### 1. Nenhuma feature `premium: true` pode ir `enabled: true` em `config/features.yml`

Features premium (ex.: `channel_voice` = chamadas WhatsApp) são **código
proprietário** do Chatwoot (pasta `enterprise/`). Ligar na imagem compartilhada =
uso em produção sem licença. Para testar/avaliar, ligue **por conta** no painel
**Super Admin** da instância — nunca no código.

> Incidente 2026-09-04: uma sessão ligou `channel_voice` no código; revertido em
> `b71fa79a4` + migração `20260904000000` que desliga a flag onde tiver rodado.

### 2. O entrypoint do container NÃO roda migração no boot

Nada de `db:migrate` / `db:chatwoot_prepare` / `db:prepare` em
`docker/entrypoints/rails.sh`. O health-check do EasyPanel mata o container
enquanto a migração ainda roda → migração fica meio aplicada → no próximo boot dá
`PG::DuplicateTable` → **crash-loop**.

> Incidente 2026-09-04: `97af31ce3` adicionou auto-migrate no boot; a instância de
> teste entrou em crash-loop `business_hour_breaks already exists`. Revertido em
> `c4de21479`.

### 3. Migrações que a gente escreve são idempotentes

Toda migração com timestamp `>= 20260903000000` usa `if_not_exists: true` em
`create_table` / `add_column` / `add_index` / `add_reference`. Assim, se rodar de
novo num banco onde aplicou parcialmente, é no-op em vez de erro.

## Procedimento de deploy (produção de cliente)

1. **Backup do banco** — EasyPanel → serviço `chatwoot-db` → aba Backups (ou
   console: `pg_dump`). O usuário já sabe fazer.
2. **Merge/push na `deploy`** → esperar o build ficar **verde** no GitHub Actions
   (`build-image.yml`). Se `fork-guardrails` falhar, o build nem roda — corrija.
3. **Trocar a imagem** dos serviços `chatwoot` e `chatwoot-sidekiq` para
   `ghcr.io/allvasc/chatwoot:latest` e **Redeploy** (força pull).
   - Confirmar: Console do serviço → `cat /app/.git_sha` deve bater com o commit
     do topo da `deploy`.
4. **Rodar a migração — MANUAL, uma vez** — Console do serviço `chatwoot`:
   ```
   bundle exec rails db:chatwoot_prepare
   ```
5. Smoke test: login, lista de conversas, Configurações → Agentes, Configurações →
   Caixa de entrada → Horário de Funcionamento.

## Puxar uma versão nova do upstream (ex.: `vX.Y.Z`)

Quando o Chatwoot lança uma versão nova e você quer trazer pro fork:

1. **Nunca direto na `deploy`.** Cria uma branch a partir dela:
   ```
   git checkout -b upgrade/vX.Y.Z deploy
   git fetch upstream --tags   # upstream = chatwoot/chatwoot
   git merge vX.Y.Z
   ```
   `merge`, não `rebase` — a `deploy` já foi usada pra buildar imagens em produção;
   rebase reescreveria histórico já publicado.

2. **Resolver conflitos com atenção redobrada nos arquivos que o fork toca:**
   - `config/features.yml` — manter `channel_voice` (e qualquer outra `premium`) em
     `enabled: false`. É o tipo de conflito que pode reintroduzir o que já foi revertido.
   - `docker/entrypoints/rails.sh` — garantir que aceitar a versão deles não traga de
     volta migração no boot.
   - `app/policies/conversation_policy.rb`, `app/services/conversations/permission_filter_service.rb`,
     `app/models/account_user.rb`, `app/builders/agent_builder.rb`,
     `app/controllers/.../agents_controller.rb`, `app/models/concerns/out_of_offisable.rb`
     — onde estão as customizações do fork.
   - `Gemfile.lock` — se o upstream mudou versão do Rails/gems, roda `bundle install`
     (local ou num Codespace) pra atualizar.

3. **Abre PR** dessa branch pra `deploy`. Isso dispara `fork-guardrails` e `fork-spec`
   automaticamente (ambos rodam em PR) — se algum conflito resolvido errado reativou
   um flag premium ou migração no boot, o CI barra ali, antes de qualquer merge.

4. **Confere as migrations novas da versão** — geralmente são aditivas, mas lê o
   changelog/PRs do release procurando algo destrutivo (rename de coluna, drop). O
   timestamp delas vem depois das migrations do fork (`20260903...`), então a ordem
   se resolve sozinha.

5. **Merge do PR** → build da imagem dispara.

6. **Ensaiar antes de qualquer cliente** — mesmo método de sempre: dump real de um
   cliente (ou o backup local do EasyPanel) → projeto descartável no EasyPanel → sobe
   a imagem nova → `db:chatwoot_prepare` → clica nas telas que esse cliente usa.

7. **Rollout cliente por cliente**, seguindo o "Procedimento de deploy" acima — imagem
   por tag de SHA (nunca `:latest` no cliente), backup, migração manual, smoke test.

### Ao criar/recriar um serviço no EasyPanel

O template do Chatwoot no EasyPanel vem com `image: chatwoot/chatwoot` **oficial**.
Depois de criar, **troque a imagem** para `ghcr.io/allvasc/chatwoot:latest` e
configure as credenciais de registry do GHCR (usuário `Allvasc`, PAT com
`read:packages`). Se esquecer, a instância sobe como Chatwoot vanilla, sem
nenhuma customização (`.git_sha` aponta para um release do upstream).

> Incidente 2026-09-04: instância de teste recriada subiu vanilla porque ficou na
> imagem oficial do template.

## Playbook — instância em crash-loop com `PG::DuplicateTable`

Sintoma: container reinicia a cada ~20s; log mostra
`relation "<tabela>" already exists` numa migração.

1. **Parar o que compete pelo lock:** EasyPanel → `chatwoot` e `chatwoot-sidekiq`
   → Stop (ou escala para 0). **Deixar `chatwoot-db` e `chatwoot-redis` no ar.**
2. **Limpar no Postgres** — Console do `chatwoot-db`:
   ```
   psql -U postgres -d chatwoot
   ```
   ```sql
   SELECT version FROM schema_migrations WHERE version LIKE '202609%' ORDER BY version;
   -- para cada tabela órfã (confirme que está vazia antes):
   SELECT count(*) FROM <tabela>;
   DROP TABLE IF EXISTS <tabela> CASCADE;
   DELETE FROM schema_migrations WHERE version IN ('<timestamp_da_migracao>');
   \q
   ```
3. **Subir** os serviços de novo com `ghcr.io/allvasc/chatwoot:latest` (imagem sem
   auto-migrate). Reativar restart / escalar sidekiq de volta.
4. **Migrar manual:** Console do `chatwoot` → `bundle exec rails db:chatwoot_prepare`.

Se o banco não tiver nada que valha preservar (instância de teste), é mais rápido
recriar: `DROP DATABASE chatwoot; CREATE DATABASE chatwoot OWNER postgres;` →
redeploy → `db:chatwoot_prepare`.

## Customizações mantidas neste fork

| Área | Commits | Resumo |
|---|---|---|
| Visibilidade de conversa por time | `1b9738be7`, `84f7309bb`, `3a64cb001` | `account_users.conversation_visibility` (`all_conversations`/`assigned_teams`); escopo por `team_members` em `PermissionFilterService` + `ConversationPolicy`; checkbox na tela de Agentes; vale para admin quando marcado. Restritos também enxergam conversas **sem time** (fila não roteada) para não ficarem no limbo — agente restrito só nas suas inboxes, admin restrito em todas. |
| Intervalos no dia + feriados nos Horários de Funcionamento | `52b4417fb`, `dae7c8358`, `5b2721371` | tabelas `business_hour_breaks` / `business_hour_holidays`; `OutOfOffisable#out_of_office_context` (prioridade feriado > intervalo > grade); UI na aba Horário de Funcionamento |

## Testes das customizações

- **`fork-spec.yml`** roda os specs afetados pelas customizações a cada PR / push na `deploy`.
  Sobe Postgres+Redis, faz `db:schema:load` **e depois `db:migrate`** (o `db/schema.rb`
  versionado não carrega as migrations do fork), e roda RSpec.
- **`db/schema.rb` está desatualizado** — não inclui as 4 migrations `20260903000000+`.
  O `fork-spec` publica um artefato `regenerated-schema-rb` a cada run; baixe e commite
  para atualizar o arquivo (precisa de um ambiente Ruby só para revisar o diff).
- Sem ambiente Ruby local? Rode os specs num **GitHub Codespace** do repo:
  `bundle exec rake db:chatwoot_prepare RAILS_ENV=test && bundle exec rspec spec/policies/conversation_policy_spec.rb spec/services/conversations/permission_filter_service_spec.rb`
