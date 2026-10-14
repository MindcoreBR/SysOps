# Mailing de campanhas — referência pública

Esta pasta descreve uma solução mínima para campanhas de email com:

- SQLite como store operacional;
- CSV/estado fora do Git;
- opt-out assinado por HMAC;
- painel administrativo protegido;
- integração com um MTA local ou provedor transacional.

## Fluxo

1. Consolidar e deduplicar contatos.
2. Remover internos, inválidos, hard bounces e opt-outs.
3. Criar uma campanha com templates texto/HTML.
4. Fazer dry-run e enviar em lotes pequenos.
5. Registrar cada tentativa, bounce, complaint e unsubscribe.
6. Nunca reutilizar endereços suprimidos.

## Segurança

Segredos ficam somente em variáveis de ambiente:

```text
OC_MAILING_UNSUBSCRIBE_SECRET=<segredo forte>
OC_MAILING_ADMIN_EMAIL=admin@example.com
OC_MAILING_PUBLIC_URL=https://mailing.example.com
```

Não versionar bancos, listas de contatos, CSVs operacionais, logs, tokens ou credenciais.

## Unsubscribe

O link contém:

```text
sha256(campaign + "|" + email + "|" + secret)
```

O endpoint valida o token antes de registrar o opt-out. Em produção, recomenda-se adicionar expiração ao token administrativo e rotação periódica do segredo.

## Operação

O painel deve permitir consultar campanhas, pesquisar contatos, registrar novos contatos, marcar opt-out e remover contatos. O disparo deve exigir confirmação explícita, limite por lote e revisão da lista final.

Veja também a implementação privada do projeto para o fluxo completo de OCI, relatórios e checkpoints.
