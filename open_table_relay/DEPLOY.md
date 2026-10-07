# Producción: Despliegue de `open_table_relay` con Docker y nginx (WSS)

Esta guía describe cómo desplegar el servidor de retransmisión y clasificación ELO (`open_table_relay`) en producción utilizando **Docker Compose**, **nginx** como proxy reverso TLS (`wss://` en el puerto `443`) y **Let's Encrypt (`certbot`)**.

---

## 1. Requisitos Previos

- Servidor Linux (Debian 12 / Ubuntu 22.04+) con los puertos `80` y `443` abiertos en el firewall.
- Un dominio apuntando a la IP pública del servidor (ej. `relay.tudominio.com`).
- Docker Engine (`24.0+`) y el plugin `docker compose` instalados.

---

## 2. Obtención de Certificados TLS con Certbot (Let's Encrypt)

Antes de levantar el contenedor de `nginx`, genera el certificado TLS para tu dominio:

```bash
sudo apt-get update && sudo apt-get install -y certbot

sudo certbot certonly --standalone \
  -d relay.tudominio.com \
  --non-interactive --agree-tos -m admin@tudominio.com
```

Los certificados quedarán almacenados en:
- `/etc/letsencrypt/live/relay.tudominio.com/fullchain.pem`
- `/etc/letsencrypt/live/relay.tudominio.com/privkey.pem`

Actualiza las directivas `ssl_certificate` y `ssl_certificate_key` en `open_table_relay/nginx/nginx.conf` con el nombre de tu dominio.

---

## 3. Configuración y Arranque con Docker Compose

1. Sitúate en la carpeta `open_table_relay/`:
   ```bash
   cd open_table_relay
   ```

2. Define el secreto `JWT_SECRET` para activar la autenticación `HS256` en producción:
   ```bash
   export JWT_SECRET="$(openssl rand -hex 32)"
   ```

3. Compila y levanta los contenedores en segundo plano:
   ```bash
   docker compose up -d --build
   ```

---

## 4. Arquitectura de Red y Seguridad

- **Puerto `80` (Público)**: Redirige automáticamente todo el tráfico a `https://` (`301 Moved Permanently`).
- **Puerto `443` (Público — WSS)**: `nginx` termina TLS 1.2/1.3 y reenvía las conexiones WebSocket (`Upgrade: websocket`) al contenedor `relay:8080` dentro de la red puente interna `relay_internal`.
- **Puerto `8081` (Solo Red Interna)**: La API HTTP de consulta de ELO (`GET /rankings/:game_id`, `GET /player/:player_id`) escucha únicamente en la red interna `relay_internal` y **no** está expuesta al exterior.
- **Volumen Persistente (`relay_sqlite_data`)**: Almacena `./data/ratings.db` de forma persistente entre reinicios o actualizaciones de imagen.

---

## 5. Verificación y Health Check

1. **Verificar estado de los contenedores**:
   ```bash
   docker compose ps
   docker compose logs -f relay
   ```

2. **Health Check del WebSocket (`wss://`)**:
   ```bash
   npx wscat -c wss://relay.tudominio.com -x '{"op":"ping"}'
   # Respuesta esperada: {"op":"pong"}
   ```

3. **Health Check de la API HTTP interna (`8081`) desde la red de Docker**:
   ```bash
   docker compose exec relay sh -c 'cat < /dev/null > /dev/tcp/127.0.0.1/8081 && echo "HTTP API 8081 OK"'
   ```
