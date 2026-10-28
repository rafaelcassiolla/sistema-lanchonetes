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

## Organização atual

- `src/components`: componentes reutilizáveis da interface.
- `src/features`: conteúdo e interface específicos de cada área funcional.
- `src/layouts`: estrutura compartilhada das páginas.
- `src/pages`: páginas da aplicação.
- `src/types`: tipos TypeScript compartilhados.
- `src/utils`: funções auxiliares sem dependência de interface.
- `src/hooks` e `src/services`: diretórios reservados, ainda sem módulos porque esta etapa não precisa de estado compartilhado nem acesso a dados.

Esta etapa é apenas visual; não inclui autenticação, banco de dados nem funcionalidades de atendimento.
