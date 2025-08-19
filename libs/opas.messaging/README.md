# OPAS Messaging Contract

## Envelope (headers)
Zorunlu header'lar:
- `x-request-id` (uuid-v4)
- `x-tenant-id` (string)
- `x-event-id` (uuid-v4)
- `x-event-type` (e.g. `PrescriptionCreated`)
- `x-event-time` (RFC3339, UTC)
- `x-schema` (e.g. `opas.events.prescription.v1.PrescriptionCreated`)

Opsiyonel:
- `x-trace-id`, `x-span-id` (W3C), `x-user-id`, `x-source`

## Kafka topics
- `opas.<context>.events.v1` (multi-tenant; tenant header'da)
- DLT: `opas.<context>.events.dlt.v1`
- Ref/lookup: `opas.<context>.ref.v1` (cleanup=compact)

## RabbitMQ
- Exchanges: `cmd.exchange`(direct), `work.exchange`(direct), `saga.exchange`(topic), `dlx.exchange`(topic)
- Retry pattern: `<queue>.retry.<ttl>` (DLX→original), DLQ: `dlq.<queue-base>`
- Örnekler definitions.json'da.

## Outbox Pattern
Her domain servisinde tablo: `outbox_events`
```sql
id uuid pk, aggregate varchar, event_type varchar, payload jsonb,
headers jsonb, occurred_at timestamptz, published_at timestamptz null
```
- TX içinde insert (domain değişikliği ile birlikte).
- Publisher job: `published_at is null` satırlarını alır, Kafka'ya gönderir, sonra `published_at` doldurur.
- Idempotency: `x-event-id` + transactional insert → `at-least-once`.

## Error Handling
- Consumer 3 kez fail → Retry queue (TTL sonra geri). Tekrar fail → DLT topic (Kafka) veya DLQ (Rabbit).

## Versiyonlama
- Proto package: `opas.events.<context>.v1`
- Major kırıcı değişiklik → `v2` topikleri ve mesaj sınıfları.
