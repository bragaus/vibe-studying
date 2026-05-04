# Deploy VPS

## Arquivos principais

- `docker-compose.prod.yml`
- `.env.prod.example`
- `deploy/nginx/vibestudying.conf`

## Ubuntu Server / Hetzner

Instale Docker e Compose plugin:

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

## Subindo a stack

No servidor:

```bash
git clone <url-do-repo> vibe-studying-backend
cd vibe-studying-backend
git switch docker
cp .env.prod.example .env.prod
```

Edite `.env.prod` com as chaves reais, SMTP, banco e domínios.

Depois suba:

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build
```

## Operação

Ver status:

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml ps
```

Ver logs:

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml logs -f backend
docker compose --env-file .env.prod -f docker-compose.prod.yml logs -f frontend
docker compose --env-file .env.prod -f docker-compose.prod.yml logs -f worker
```

Atualizar deploy:

```bash
git pull
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build
```

## Certificados

O Nginx da stack monta `/etc/letsencrypt` do host em modo leitura e usa:

- `/etc/letsencrypt/live/vibestudying.com.br/fullchain.pem`
- `/etc/letsencrypt/live/vibestudying.com.br/privkey.pem`
- `/etc/letsencrypt/live/backendvibestudying.planoartistico.com.br/fullchain.pem`
- `/etc/letsencrypt/live/backendvibestudying.planoartistico.com.br/privkey.pem`

Se o Certbot renovar os certificados, reinicie o Nginx da stack para recarregar os arquivos:

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml restart nginx
```
