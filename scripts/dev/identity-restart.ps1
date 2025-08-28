# Derle + ayağa kaldır (tek hamle)
$files = @(
  "platform/docker-compose.dev.yaml",
  "platform/compose.identity.override.yml"
)

docker compose -f $files[0] -f $files[1] up -d --build identity-api
