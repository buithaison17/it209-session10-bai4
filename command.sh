
#!/bin/bash
set -e

NETWORK="app-net"
VOLUME="db-data"
DB="db-server"
APP="app-container"

DB_NAME="appdb"
DB_USER="appuser"
DB_PASSWORD="apppassword"

echo "=== 1. Create network and volume ==="
docker network inspect "$NETWORK" >/dev/null 2>&1 || docker network create "$NETWORK"
docker volume inspect "$VOLUME" >/dev/null 2>&1 || docker volume create "$VOLUME"

echo "=== 2. Remove old containers ==="
docker rm -f "$APP" "$DB" 2>/dev/null || true

echo "=== 3. Start PostgreSQL ==="
docker run -d \
  --name "$DB" \
  --network "$NETWORK" \
  -e POSTGRES_DB="$DB_NAME" \
  -e POSTGRES_USER="$DB_USER" \
  -e POSTGRES_PASSWORD="$DB_PASSWORD" \
  -v "$VOLUME":/var/lib/postgresql/data \
  --health-cmd="pg_isready -U $DB_USER -d $DB_NAME" \
  --health-interval=5s \
  --health-timeout=3s \
  --health-retries=20 \
  postgres:15-alpine

echo "=== 4. Wait for PostgreSQL ==="
until [ "$(docker inspect -f '{{.State.Health.Status}}' "$DB")" = "healthy" ]; do
  sleep 2
done

echo "=== 5. Insert test data ==="
docker exec -e PGPASSWORD="$DB_PASSWORD" "$DB" \
  psql -U "$DB_USER" -d "$DB_NAME" -c \
  "CREATE TABLE IF NOT EXISTS persistence_test (id SERIAL PRIMARY KEY, message TEXT);"

docker exec -e PGPASSWORD="$DB_PASSWORD" "$DB" \
  psql -U "$DB_USER" -d "$DB_NAME" -c \
  "INSERT INTO persistence_test (id, message) VALUES (1, 'Data persists!')
   ON CONFLICT (id) DO UPDATE SET message = EXCLUDED.message;"

echo "=== 6. Start backend network test container ==="
docker run -d \
  --name "$APP" \
  --network "$NETWORK" \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  alpine:3.20 sh -c "apk add --no-cache iputils >/dev/null && sleep infinity"

echo "=== 7. Test DNS ==="
docker exec "$APP" ping -c 2 db-server

echo "=== 8. Delete database container ==="
docker rm -f "$DB"

echo "=== 9. Recreate database using the same volume ==="
docker run -d \
  --name "$DB" \
  --network "$NETWORK" \
  -e POSTGRES_DB="$DB_NAME" \
  -e POSTGRES_USER="$DB_USER" \
  -e POSTGRES_PASSWORD="$DB_PASSWORD" \
  -v "$VOLUME":/var/lib/postgresql/data \
  --health-cmd="pg_isready -U $DB_USER -d $DB_NAME" \
  --health-interval=5s \
  --health-timeout=3s \
  --health-retries=20 \
  postgres:15-alpine

echo "=== 10. Wait for recreated database ==="
until [ "$(docker inspect -f '{{.State.Health.Status}}' "$DB")" = "healthy" ]; do
  sleep 2
done

echo "=== 11. Verify persisted data ==="
docker exec -e PGPASSWORD="$DB_PASSWORD" "$DB" \
  psql -U "$DB_USER" -d "$DB_NAME" -c \
  "SELECT * FROM persistence_test;"

echo "=== 12. Verify network and volume ==="
docker network ls | grep "$NETWORK"
docker volume ls | grep "$VOLUME"
docker network inspect "$NETWORK"

echo "SUCCESS: Docker network and volume persistence verified!"
