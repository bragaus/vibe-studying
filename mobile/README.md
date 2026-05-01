# Mobile - Vibe Studying

App Flutter focado no aluno, com:

- login e cadastro
- onboarding de gostos
- feed personalizado
- pratica estilo HUD/karaoke
- cache local de profile, feed e lesson
- fila offline de tentativas

## Estado Atual

O projeto Flutter ja possui runners versionados para:

- Linux
- Android
- iOS

Voce nao precisa rodar `flutter create .` para usar o repositorio atual.

## Instalando O Flutter No Linux

### Dependencias Do Sistema

Exemplo para Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y curl git unzip xz-utils zip libglu1-mesa clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```

Esses pacotes cobrem o necessario para Flutter desktop Linux e builds locais comuns.

### Instalando O SDK Flutter

Opcao recomendada usando o canal stable oficial:

```bash
mkdir -p "$HOME/development"
git clone https://github.com/flutter/flutter.git -b stable "$HOME/development/flutter"
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
flutter --version
```

### Habilitando Linux Desktop

```bash
flutter config --enable-linux-desktop
flutter doctor -v
```

Se o `flutter doctor` apontar dependencia faltando, resolva antes de seguir.

## Instalacao Do Projeto

```bash
cd mobile
flutter pub get
```

## Como O App Recebe A URL Do Backend

O app nao usa `.env` no estado atual.

A URL do backend pode ser configurada de duas formas:

- via `--dart-define=API_BASE_URL=...`
- pelo botao de configuracao de backend dentro do app

Exemplo local para Linux desktop:

```bash
flutter run -d linux --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

## Rodando No Linux Desktop

```bash
cd mobile
flutter run -d linux --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Quando o app abrir, voce podera:

- logar
- cadastrar aluno
- concluir onboarding
- consumir o feed personalizado
- abrir lessons

## Limitacao Atual No Linux

O projeto usa `speech_to_text` na tela de pratica, mas a configuracao atual do app nao registra plugin Linux para esse recurso.

Na pratica isso significa:

- Linux desktop e util para validar bootstrap, auth, onboarding, feed e integracao com a API
- o fluxo de microfone e pratica de voz pode ficar limitado ou indisponivel no Linux
- para testar reconhecimento de fala de forma mais confiavel, prefira Android ou iOS

## Rodando No Android

Se voce estiver usando emulador Android local:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

Observacao:

- `10.0.2.2` aponta do emulador Android para o host local
- nao use `localhost` diretamente dentro do emulador

## Rodando Em iPhone Fisico

O projeto iOS ja esta no repositorio. O passo final precisa ser feito em um Mac com Xcode.

Passos:

1. Abra `mobile/ios/Runner.xcworkspace` no Xcode.
2. Selecione seu `Team` em `Signing & Capabilities`.
3. Ajuste o `Bundle Identifier` se houver conflito.
4. Conecte o iPhone via USB e habilite `Developer Mode`.
5. Rode o app com o IP real da maquina que esta executando o backend.

Exemplo:

```bash
flutter run -d <iphone-id> --dart-define=API_BASE_URL=http://SEU_IP_LOCAL:8000/api
```

## Testes

```bash
cd mobile
flutter test
```

## Dicas De Desenvolvimento

- se o backend estiver em outra maquina, use o IP dela no `API_BASE_URL`
- o app tambem permite trocar a URL do backend por UI
- o feed sincroniza submissions pendentes antes de recarregar conteudo
- o mobile persiste sessao em secure storage e cache em shared preferences
