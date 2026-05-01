# Frontend - Vibe Studying

Frontend em React 18 + Vite responsavel pela landing publica, auth web e portal autenticado de distribuicao dos apps Android.

## Stack

- Node.js 20+
- npm 10+
- React 18
- Vite
- TypeScript
- Tailwind CSS
- shadcn/ui

## Instalando Node.js 20 Em Linux

Uma forma pratica em Ubuntu/Debian e usar `nvm`:

```bash
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 20
nvm use 20
node -v
npm -v
```

## Instalacao Do Projeto

```bash
cd frontend
cp .env.example .env
npm install
```

## Variaveis De Ambiente

Arquivo usado pelo projeto: `frontend/.env`

Exemplo local:

```env
VITE_API_URL=http://127.0.0.1:8000/api
VITE_ANDROID_APP_URL=
VITE_FLUTTER_ANDROID_URL=
```

### O Que Cada Variavel Faz

| Variavel | Obrigatoria | Uso |
| --- | --- | --- |
| `VITE_API_URL` | sim | URL base da API Django Ninja |
| `VITE_ANDROID_APP_URL` | nao | link para APK Android no portal autenticado |
| `VITE_FLUTTER_ANDROID_URL` | nao | link para build Flutter Android no portal autenticado |

### Observacoes Importantes

- `VITE_API_URL` precisa apontar para a API com o sufixo `/api`
- se `VITE_ANDROID_APP_URL` ou `VITE_FLUTTER_ANDROID_URL` ficarem vazias, o portal exibira `LINK::PENDING_CONFIG`
- para desenvolvimento local com backend na mesma maquina, a configuracao mais comum e `http://127.0.0.1:8000/api`

## Rodando Em Desenvolvimento

```bash
cd frontend
npm run dev
```

Acesse a URL exibida pelo Vite. Normalmente sera `http://127.0.0.1:8080`.

## Scripts Disponiveis

```bash
npm run dev
npm run test
npm run build
npm run preview
npm run lint
```

## O Que O Frontend Entrega Hoje

- landing publica
- CTA de waitlist conectado ao backend
- auth web para aluno
- portal autenticado simples para links Android

## O Que O Frontend Ainda Nao Entrega

- feed de estudo no web
- onboarding no web
- painel completo de professor
- dashboard de progresso do aluno

## Fluxo Local Recomendado

1. Suba o backend primeiro em `http://127.0.0.1:8000`.
2. Configure `VITE_API_URL=http://127.0.0.1:8000/api`.
3. Rode `npm run dev`.
4. Teste a landing, waitlist e auth web.

## Testes E Build

```bash
cd frontend
npm run test
npm run build
```
