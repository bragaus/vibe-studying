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
