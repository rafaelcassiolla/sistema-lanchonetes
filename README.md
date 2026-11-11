# Atendimento para Lanchonetes

Aplicação web inicial construída com React, TypeScript, Vite e Tailwind CSS 4.

## Executar localmente

```bash
npm install
npm run dev
```

O Vite informa no terminal o endereço local para abrir no navegador.

## Verificações

```bash
npm run build
npm run lint
```

## Supabase local

A configuração local do Supabase fica em `supabase/config.toml`. Para iniciar os serviços locais, instale o Supabase CLI e o Docker Desktop e execute:

```bash
supabase start
supabase status
```

Copie `.env.example` para `.env.local` e preencha as credenciais locais exibidas por `supabase status`. Não versione `.env.local` nem use uma chave `service_role` em variáveis `VITE_*`; essas variáveis são incorporadas ao bundle do navegador.

## Organização atual

- `src/components`: componentes reutilizáveis da interface.
- `src/features`: conteúdo e interface específicos de cada área funcional.
- `src/layouts`: estrutura compartilhada das páginas.
- `src/pages`: páginas da aplicação.
- `src/types`: tipos TypeScript compartilhados.
- `src/utils`: funções auxiliares sem dependência de interface.
- `src/hooks` e `src/services`: diretórios reservados, ainda sem módulos porque esta etapa não precisa de estado compartilhado nem acesso a dados.

Esta etapa é apenas visual; não inclui autenticação, banco de dados nem funcionalidades de atendimento.
