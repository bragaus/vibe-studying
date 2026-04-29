# Vibe Studying Mobile

App Flutter focado no aluno, com:

- login e cadastro
- onboarding de gostos
- feed personalizado
- prática estilo karaoke/HUD

## Estado atual

O código Flutter foi estruturado manualmente neste repositório porque o binário `flutter` não está disponível no ambiente atual do agente.

Isso significa que os fontes do app já estão prontos em `lib/`, mas os diretórios nativos padrão (`android/`, `ios/`, etc.) ainda precisam ser gerados na sua máquina com Flutter instalado.

## Como finalizar o bootstrap localmente

Com Flutter instalado, rode dentro de `mobile/`:

```bash
flutter create .
flutter pub get
```

Depois rode o app com:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

Use `10.0.2.2` no emulador Android para apontar para o backend local.

## iPhone fisico

O projeto iOS ja esta preparado para testes locais com:

- permissao de microfone
- permissao de reconhecimento de fala
- acesso HTTP ao backend local durante desenvolvimento
- bundle identifier configurado como `com.bragaus.vibestudyingmobile`

Para instalar no iPhone, o passo final precisa ser feito em um Mac com Xcode:

1. abra `mobile/ios/Runner.xcworkspace`
2. selecione seu `Team` em `Signing & Capabilities`
3. ajuste o `Bundle Identifier` se o Xcode reclamar de conflito
4. conecte o iPhone via USB e habilite `Developer Mode`
5. rode o app com:

```bash
flutter run -d <iphone-id> --dart-define=API_BASE_URL=http://SEU_IP_UBUNTU:8000/api
```

No iPhone fisico, nunca use `10.0.2.2`; use o IP real do Ubuntu na mesma rede.
