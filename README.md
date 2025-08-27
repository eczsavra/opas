# OPAS - Microservices Platform

## 🚀 Proje Hakkında

OPAS, modern microservices mimarisi ile geliştirilmiş, event-driven, güvenli ve ölçeklenebilir bir platformdur.

## 🏗️ Mimari Özellikler

- **3 Şerit Gateway**: Kong (API Gateway), EMQX (IoT Gateway), Istio (Service Mesh)
- **Event-Driven Architecture**: Redpanda/Kafka + RabbitMQ + Temporal + Debezium
- **Database**: DB-per-tenant PostgreSQL + Shared DB + OpenSearch + Redis + MinIO
- **Observability**: OpenTelemetry (OTel) ile distributed tracing
- **Security**: KVKK uyumlu, Medula sabit IP desteği
- **Patterns**: Outbox + Idempotency + Dead Letter Queue (DLQ)

## 🛠️ Teknoloji Stack'i

### Backend
- **.NET 8** (ASP.NET Core) - Ana microservices
- **Python** - AI/ML servisleri

### Infrastructure
- **Kubernetes** - Container orchestration
- **Helm** - Package management
- **Istio** - Service mesh
- **Kong** - API Gateway
- **EMQX** - IoT Gateway
- **Temporal** - Workflow orchestration
- **Debezium** - Change data capture
- **Redpanda/Kafka** - Event streaming
- **RabbitMQ** - Message queuing

### Database & Storage
- **PostgreSQL** - Ana veritabanı (DB-per-tenant)
- **OpenSearch** - Logging ve arama
- **Redis** - Caching
- **MinIO** - Object storage

### Monitoring & Observability
- **OpenTelemetry** - Distributed tracing
- **Grafana** - Monitoring dashboard
- **Prometheus** - Metrics collection

## 📁 Proje Yapısı

```
opas/
├── apps/                    # Microservices uygulamaları
│   ├── api-gateway/        # Kong API Gateway
│   ├── auth-service/       # Kimlik doğrulama servisi
│   ├── user-service/       # Kullanıcı yönetimi
│   ├── notification-service/ # Bildirim servisi
│   └── ai-service/         # Python AI servisi
├── libs/                   # Paylaşılan kütüphaneler
│   ├── opas.abstractions/  # Domain abstractions
│   ├── opas.messaging/     # Event messaging
│   ├── opas.security/      # Güvenlik utilities
│   ├── opas.observability/ # Observability tools
│   └── opas.testing/       # Test utilities
├── platform/               # Platform bileşenleri
│   ├── helm/              # Helm charts
│   ├── k8s/               # Kubernetes manifests
│   ├── kong/              # Kong configurations
│   ├── emqx/              # EMQX configurations
│   ├── istio/             # Istio configurations
│   ├── opensearch/        # OpenSearch configs
│   ├── flyway/            # Database migrations
│   ├── temporal/          # Temporal workflows
│   ├── vault/             # HashiCorp Vault configs
│   └── grafana/           # Grafana dashboards
├── proto/                 # Protocol Buffers
├── openapi/               # OpenAPI specifications
├── .github/workflows/     # CI/CD pipelines
├── Makefile               # Build automation
├── .editorconfig          # Editor configuration
├── .gitignore             # Git ignore rules
├── README.md              # Bu dosya
├── RUNBOOK.md             # Operasyonel rehber
├── SECURITY.md            # Güvenlik rehberi
└── .cursorrules           # Coding standards
```

## 🚀 Hızlı Başlangıç

### Gereksinimler
- .NET 8 SDK
- Python 3.11+
- Docker & Docker Compose
- Kubernetes cluster
- Helm 3.x

### Kurulum

```bash
# Repository'yi klonlayın
git clone <repository-url>
cd opas

# Gerekli araçları yükleyin
make setup

# Geliştirme ortamını başlatın
make dev-up

# Servisleri test edin
make test
```

## 📋 Geliştirme Rehberi

### Yeni Servis Ekleme
```bash
# .NET servisi oluşturma
make create-service name=my-service type=dotnet

# Python servisi oluşturma
make create-service name=my-ai-service type=python
```

### Test Çalıştırma
```bash
# Tüm testleri çalıştır
make test

# Belirli servisin testlerini çalıştır
make test-service service=user-service
```

## 🔧 Operasyonel Komutlar

```bash
# Geliştirme ortamı
make dev-up          # Ortamı başlat
make dev-down        # Ortamı durdur
make dev-logs        # Logları görüntüle

# Production
make deploy          # Production'a deploy et
make rollback        # Rollback yap
make health-check    # Sağlık kontrolü

# Monitoring
make logs            # Tüm logları görüntüle
make metrics         # Metrikleri görüntüle
make traces          # Distributed traces
```

## 🔒 Güvenlik

- KVKK uyumlu veri işleme
- Medula sabit IP desteği
- JWT tabanlı kimlik doğrulama
- Rate limiting ve throttling
- Input validation ve sanitization

## 📊 Monitoring & Observability

- OpenTelemetry ile distributed tracing
- Structured logging
- Metrics collection
- Health checks
- Alerting

## 🌐 Development Stack URLs

Geliştirme ortamını başlattıktan sonra (`make up`) aşağıdaki servislere erişebilirsiniz:

- **Grafana**: [http://localhost:3000](http://localhost:3000) (admin/admin)
- **Jaeger**: [http://localhost:16686](http://localhost:16686)
- **Redpanda Console**: [http://localhost:8080](http://localhost:8080)
- **RabbitMQ Mgmt**: [http://localhost:15672](http://localhost:15672) (opas/opas123)
- **OpenSearch Dashboards**: [http://localhost:5601](http://localhost:5601) (admin/admin123)
- **MinIO Console**: [http://localhost:9001](http://localhost:9001) (opas/opas12345)
- **EMQX Dashboard**: [http://localhost:18083](http://localhost:18083) (admin/public)
- **Temporal UI**: [http://localhost:8233](http://localhost:8233)
- **Kong Admin**: [http://localhost:8001](http://localhost:8001)
- **Vault**: [http://localhost:8200](http://localhost:8200) (dev-root)

## 🤝 Katkıda Bulunma

1. Fork yapın
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Değişikliklerinizi commit edin (`git commit -m 'Add amazing feature'`)
4. Branch'inizi push edin (`git push origin feature/amazing-feature`)
5. Pull Request oluşturun

## 📄 Lisans

Bu proje [MIT License](LICENSE) altında lisanslanmıştır.

## 📞 İletişim (+90 549 870 35 55)

- **Proje Yöneticisi**: [İsim] - [Email]
- **Teknik Lider**: [İsim] - [Email]
- **DevOps**: [İsim] - [Email]

## Unicode ★ klasörleri (opsiyonel ASCII fallback)

Kontrol-düzlemi servisleri şu an `★-` prefix'i ile adlandırılmıştır. Bu klasörler normal şartlarda değiştirilmez, ancak CI/CD araçları veya geliştirme ortamlarında Unicode karakter desteği sorunu yaşanırsa, aşağıdaki komutlardan biriyle **tek seferlik** ASCII'ye dönüştürülebilir:

### Bash (Linux/macOS):
```bash
chmod +x tools/rename-star-folders.sh
./tools/rename-star-folders.sh
```

### PowerShell (Windows):
```powershell
pwsh ./tools/rename-star-folders.ps1
```

**Not**: Bu işlem sonrasında solution dosyaları ve pipeline referanslarını güncellemeniz gerekebilir.

---

**OPAS Team** - Modern Microservices Platform
