# Tech Specs

## Objetivo

Construir um app Flutter focado no aluno, com o seguinte fluxo principal:

1. login
2. cadastro
3. onboarding de gostos
4. feed personalizado
5. prática de pronúncia estilo Guitar Hero/Karaoke
6. pausa guiada por IA quando houver erro de palavra ou pronúncia

O objetivo do build inicial nao e resolver tudo em tempo real no primeiro commit. A estrategia correta e entregar em camadas, reaproveitando o backend Django Ninja que ja existe.

## Estado Atual Do Repositorio

- O backend ja expoe autenticacao JWT em `/api/auth/*`.
- O backend ja tem `Lesson`, `Exercise` e `Submission`.
- O feed atual (`GET /api/feed`) e publico e nao personalizado.
- Cada `Lesson` tem exatamente um `Exercise`.
- O `Exercise` atual suporta apenas uma frase principal (`expected_phrase_en` / `expected_phrase_pt`).

Esse ultimo ponto e o principal gap tecnico para a experiencia tipo Guitar Hero: a pratica desejada precisa de varias linhas por exercicio, em ordem, com velocidade progressiva e feedback por linha.

## Decisoes De Produto Para O MVP Mobile

- O app Flutter sera student-only no primeiro ciclo.
- O cadastro do mobile usa apenas `POST /api/auth/register`.
- Professor continua gerindo conteudo pela web/admin/backend; o app mobile nao tera CRUD de lessons.
- O onboarding sera obrigatorio antes do feed personalizado.
- O primeiro slice de pratica sera online-first.
- Offline-first entra como segunda fase: cache local de feed + fila de tentativas pendentes.

## Arquitetura Do Mobile

### Stack

- Flutter 3.x
- `flutter_riverpod` para estado
- `go_router` para navegacao
- `dio` para HTTP
- `flutter_secure_storage` para tokens
- `record` para captura de audio
- `permission_handler` para permissoes
- `just_audio` para audio de referencia
- `web_socket_channel` para streaming em tempo real na fase 2
- `freezed` + `json_serializable` para modelos tipados

### Estrutura De Pastas Recomendada

```text
mobile/
  lib/
    app/
      router/
      theme/
      bootstrap/
    core/
      api/
      auth/
      config/
      errors/
      storage/
      utils/
    features/
      auth/
        data/
        domain/
        presentation/
      onboarding/
        data/
        domain/
        presentation/
      feed/
        data/
        domain/
        presentation/
      practice/
        data/
        domain/
        presentation/
      profile/
        data/
        domain/
        presentation/
    shared/
      widgets/
      models/
```

### Configuracao De Ambiente

Para o app Flutter, preferir `--dart-define` em vez de `flutter_dotenv` no primeiro ciclo.

Valores previstos:

- `API_BASE_URL`
- `WS_BASE_URL`

Exemplo local:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api \
  --dart-define=WS_BASE_URL=ws://10.0.2.2:8000/ws
```

Observacao: no emulador Android, `10.0.2.2` aponta para o host local. Nao usar `localhost` no app Android.

## Design System Mobile

O app Flutter deve herdar a linguagem da landing web ja existente.

### Tokens Visuais

Baseados no `frontend/src/index.css`:

- background profundo roxo escuro
- neon pink como cor primaria
- neon cyan como cor secundaria
- accent amarelo eletrico
- tipografia display agressiva para titulos
- HUD panels com blur, bordas semi-transparentes e glow

### Implementacao No Flutter

- Criar `AppPalette` com cores equivalentes ao CSS.
- Criar `AppTheme` com:
  - `ColorScheme.dark`
  - componentes com borda fina e glow
  - `TextTheme` com uma fonte display e uma mono
- Criar widgets reutilizaveis:
  - `HudScaffold`
  - `HudPanel`
  - `NeonButton`
  - `HudBadge`
  - `GlowProgressBar`

## Fluxo De Navegacao

### Rotas

- `/splash`
- `/login`
- `/register`
- `/onboarding`
- `/feed`
- `/practice/:lessonSlug`
- `/profile`

### Regras De Redirect

- sem token: `/login`
- com token e sem onboarding completo: `/onboarding`
- com token e onboarding completo: `/feed`

O `go_router` deve consultar um `sessionProvider` e um `profileProvider` para decidir os redirects.

## Estado Global

### Providers Principais

- `dioProvider`
- `authRepositoryProvider`
- `sessionControllerProvider`
- `profileRepositoryProvider`
- `profileControllerProvider`
- `feedRepositoryProvider`
- `personalizedFeedProvider`
- `practiceSessionControllerProvider`

### Sessao

Persistir em `flutter_secure_storage`:

- access token
- refresh token
- user id
- user role

O `dio` precisa de interceptor para:

1. anexar `Authorization: Bearer <token>`
2. tentar `POST /api/auth/refresh` uma unica vez em resposta `401`
3. deslogar se refresh falhar

## Modelagem Mobile

### Modelos Basicos

```text
AppUser
- id
- email
- firstName
- lastName
- role

StudentProfile
- userId
- onboardingCompleted
- englishLevel
- favoriteSongs[]
- favoriteMovies[]
- favoriteSeries[]
- favoriteAnime[]
- favoriteArtists[]
- favoriteGenres[]

FeedItem
- id
- slug
- title
- description
- contentType
- mediaUrl
- teacherName
- difficulty
- matchReason
- tags[]

ExerciseLine
- id
- order
- textEn
- textPt
- phoneticHint
- referenceStartMs
- referenceEndMs

PracticeResult
- lessonSlug
- accuracy
- pronunciationScore
- wrongWords[]
- coachMessage
```

## Mudancas Necessarias No Backend

### 1. Perfil Do Aluno

Adicionar um novo app ou modulo de perfil com um model `StudentProfile`.

Para o MVP, usar `JSONField` para listas de gosto. E a solucao mais rapida e boa o suficiente nesta fase.

```text
StudentProfile
- user (OneToOne com accounts.User)
- onboarding_completed (bool)
- english_level (char)
- favorite_songs (JSONField)
- favorite_movies (JSONField)
- favorite_series (JSONField)
- favorite_anime (JSONField)
- favorite_artists (JSONField)
- favorite_genres (JSONField)
```

Motivo: o usuario quer descrever gostos livres como musicas, filmes, series e animes favoritos. Normalizar tudo agora atrasaria o build. Se a curadoria crescer, podemos migrar depois para tags normalizadas.

### 2. Feed Personalizado

O `GET /api/feed` atual nao basta para o app.

Adicionar:

- `GET /api/profile/me`
- `PUT /api/profile/me`
- `POST /api/profile/onboarding`
- `GET /api/feed/personalized`

### 3. Conteudo De Series

`Lesson.ContentType` hoje tem:

- `charge`
- `music`
- `movie_clip`
- `anime_clip`

Adicionar `series_clip`, porque o onboarding e o feed precisam representar series favoritas explicitamente.

### 4. Exercicio Com Varias Linhas

O `Exercise` atual tem apenas uma frase esperada. Para a experiencia tipo Guitar Hero, adicionar uma tabela filha ordenada.

```text
ExerciseLine
- exercise (FK)
- order (int)
- text_en
- text_pt
- phonetic_hint
- reference_start_ms
- reference_end_ms
```

Regras:

- um `Exercise` continua pertencendo a uma unica `Lesson`
- um `Exercise` passa a ter varias `ExerciseLine`
- o app toca/mostra essas linhas na ordem crescente de `order`

### 5. Persistencia Das Tentativas

Nao vale persistir cada parcial de transcript no banco desde o inicio.

Manter `Submission` como resumo da tentativa completa e adicionar feedback por linha.

```text
SubmissionLine
- submission (FK)
- exercise_line (FK)
- transcript_en
- accuracy_score
- pronunciation_score
- wrong_words (JSONField)
- feedback (JSONField)
- status
```

Beneficio: reaproveita o dominio atual de `Submission` sem inventar um segundo conceito concorrente para tentativa.

## Contrato De API Proposto

### Auth

Ja existentes e reaproveitados sem mudanca:

- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `GET /api/auth/me`

### Profile

#### `GET /api/profile/me`

Resposta:

```json
{
  "user": {
    "id": 1,
    "email": "student@example.com",
    "first_name": "Ana",
    "last_name": "Silva",
    "role": "student"
  },
  "profile": {
    "onboarding_completed": false,
    "english_level": "beginner",
    "favorite_songs": [],
    "favorite_movies": [],
    "favorite_series": [],
    "favorite_anime": [],
    "favorite_artists": [],
    "favorite_genres": []
  }
}
```

#### `PUT /api/profile/me`

Payload:

```json
{
  "english_level": "beginner",
  "favorite_songs": ["Numb", "Yellow"],
  "favorite_movies": ["Interstellar"],
  "favorite_series": ["Breaking Bad"],
  "favorite_anime": ["Naruto"],
  "favorite_artists": ["Linkin Park"],
  "favorite_genres": ["rock", "sci-fi"]
}
```

#### `POST /api/profile/onboarding`

Mesmo payload do update, mas finaliza com `onboarding_completed=true`.

### Feed

#### `GET /api/feed/personalized?cursor=123&limit=10`

Resposta:

```json
{
  "items": [
    {
      "id": 10,
      "slug": "numb-linkin-park-intro",
      "title": "Numb - chorus practice",
      "description": "Treine a frase principal do refrão.",
      "content_type": "music",
      "media_url": "https://...",
      "teacher_name": "Coach AI",
      "difficulty": "easy",
      "match_reason": "matches favorite artist",
      "tags": ["linkin park", "rock", "music"]
    }
  ],
  "next_cursor": 9
}
```

### Practice MVP

#### `GET /api/lessons/{slug}`

Ampliar a resposta para incluir `exercise.lines`.

#### `POST /api/submissions`

Continuar criando a tentativa principal, mas aceitar dados agregados da sessao.

Payload esperado na fase 1:

```json
{
  "exercise_id": 42,
  "transcript_en": "I tried all lines in sequence",
  "transcript_pt": "",
  "line_results": [
    {
      "exercise_line_id": 100,
      "transcript_en": "Hello from the other side",
      "accuracy_score": 84,
      "pronunciation_score": 79,
      "wrong_words": ["other"],
      "feedback": {
        "coach_message": "Encoste a lingua para o som th em other"
      }
    }
  ]
}
```

### Practice Realtime - Fase 2

Adicionar websocket apenas depois do MVP de frase-a-frase funcionar.

- `WS /api/practice/stream/{submission_id}`

Eventos previstos:

- `session.started`
- `transcript.partial`
- `line.match_progress`
- `line.failed`
- `coach.feedback`
- `session.completed`

## Algoritmo Inicial De Personalizacao

O feed inicial pode ser simples e deterministico. Nao precisa de ML no primeiro ciclo.

Score sugerido por lesson:

- `+5` se a franquia/titulo bater exatamente com gosto do aluno
- `+4` se artista bater exatamente
- `+3` se categoria bater (`music`, `movie_clip`, `series_clip`, `anime_clip`)
- `+2` se tags de genero baterem
- `+2` se o aluno errou essa lesson anteriormente e precisa revisar
- `-3` se a lesson foi concluida com score alto recentemente

Ordenar por score desc e usar `created_at` como desempate.

## Fluxo Da Tela De Pratica

### Objetivo

Entregar a sensacao de Guitar Hero/Karaoke, mas baseada em frases de cultura pop que o aluno gosta.

### Componentes Da Tela

- topo com combo, score e velocidade
- lane central com linhas descendo
- destaque da linha atual
- preenchimento karaoke por palavra correta
- mic status no rodape
- modal ou bottom sheet de coach IA ao detectar erro

### Logica Da Fase 1

Sem streaming real ainda:

1. a linha desce com `AnimationController`
2. o aluno grava a linha
3. o app envia o audio ao backend ou envia o transcript retornado pelo STT
4. o backend responde com score e feedback
5. o app pinta a linha como correta ou pausa para coaching

### Logica Da Fase 2

Com streaming:

1. o microfone fica aberto
2. o backend recebe audio incremental
3. o provider de STT devolve transcript parcial
4. o app vai preenchendo a frase em tempo real
5. se a divergencia persistir acima do threshold, a sessao pausa

## IA E Pronuncia

### Regra Pratica

Nao construir modelo proprio agora.

Usar um provider pronto de speech/pronunciation para o MVP. Recomendacao principal:

- Azure Speech Pronunciation Assessment

Alternativas:

- Speechace
- Deepgram + camada pedagogica propria

### Responsabilidades Da IA

- transcrever a fala
- calcular score geral
- calcular score por palavra
- apontar palavras problemáticas
- devolver feedback curto e pedagogico em pt-BR

### Formato De Feedback Esperado

```json
{
  "accuracy_score": 81,
  "pronunciation_score": 77,
  "wrong_words": ["thought"],
  "coach_message": "Em thought, faca o th com a lingua entre os dentes e mantenha o som aberto de o.",
  "phonetic_hint": "thot"
}
```

## Offline-First Em Fases

### Fase 1

- tokens persistidos localmente
- cache simples do ultimo perfil
- cache simples das ultimas lessons abertas

### Fase 2

- persistir feed recente localmente
- baixar audio/textos das lessons favoritas
- fila local de `Submission` pendente quando offline

Nao tentar implementar sincronizacao completa offline no primeiro build do app.

## Plano De Entrega

### Marco 0 - Bootstrap

1. criar pasta `mobile/`
2. configurar Riverpod, GoRouter, Dio e SecureStorage
3. portar tema cyberpunk para Flutter
4. criar `Splash`, `Login` e `Register`

### Marco 1 - Auth Fechado

1. integrar `register`, `login`, `refresh`, `me`
2. guardar tokens com refresh automatico
3. bloquear app para role `student`
4. redirect para onboarding apos cadastro/login

### Marco 2 - Onboarding

1. criar `StudentProfile` no backend
2. criar endpoints `/api/profile/*`
3. tela multipasso de gostos
4. salvar gostos e marcar `onboarding_completed`

### Marco 3 - Feed Personalizado

1. criar ranking simples no backend
2. adicionar metadados de tags/dificuldade nas lessons
3. criar feed mobile com cards HUD
4. CTA `Praticar agora`

### Marco 4 - Pratica MVP

1. adicionar `ExerciseLine`
2. adaptar detalhe da lesson para varias linhas
3. criar tela de pratica com animacao de descida
4. gravar audio por linha
5. avaliar linha e mostrar coach IA
6. salvar tentativa final em `Submission`

### Marco 5 - Realtime

1. websocket de pratica
2. transcript parcial em tempo real
3. preenchimento karaoke por palavra
4. pausa automatica por erro

### Marco 6 - Offline E Polimento

1. cache local do feed
2. fila de submissao pendente
3. analytics basico de progresso
4. polimento de animacoes, sons e HUD

## Ordem Recomendada De Implementacao No Modo Build

1. criar `mobile/` com tema, router e auth
2. adicionar `StudentProfile` e endpoints de perfil no backend
3. implementar onboarding Flutter
4. criar feed personalizado no backend
5. implementar feed Flutter
6. adicionar `ExerciseLine` e adaptar detail endpoint
7. implementar pratica frase-a-frase
8. integrar IA de pronuncia
9. evoluir para realtime

## Comandos Iniciais

```bash
flutter create mobile
cd mobile
flutter pub add flutter_riverpod go_router dio flutter_secure_storage record permission_handler just_audio web_socket_channel freezed_annotation json_annotation
flutter pub add --dev build_runner freezed json_serializable
```

Para rodar localmente em Android emulator:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api \
  --dart-define=WS_BASE_URL=ws://10.0.2.2:8000/ws
```

## Primeiro Slice Que Deve Ser Construido Agora

Se o proximo passo for implementacao, a ordem ideal e:

1. criar o app Flutter em `mobile/`
2. montar tema cyberpunk HUD
3. integrar login/cadastro com o backend atual
4. adicionar `StudentProfile` no backend
5. construir onboarding de gostos

Esse caminho entrega valor rapido, reduz risco e prepara o terreno para o feed personalizado e a pratica estilo Guitar Hero sem forcar arquitetura prematura.
