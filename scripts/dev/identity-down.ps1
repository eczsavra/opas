# Identity API container'ını durdur + kaldır (diğer servisler etkilenmez)
$files = @(
  "platform/docker-compose.dev.yaml",
  "platform/compose.identity.override.yml"
)

docker compose -f $files[0] -f $files[1] stop identity-api
docker compose -f $files[0] -f $files[1] rm -f identity-api
