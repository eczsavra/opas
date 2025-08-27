# OPAS - Operasyonel Rehber (Runbook)

## 📋 İçindekiler

1. [Hızlı Başlangıç](#hızlı-başlangıç)
2. [Geliştirme Ortamı](#geliştirme-ortamı)
3. [Production Deployment](#production-deployment)
4. [Monitoring & Alerting](#monitoring--alerting)
5. [Troubleshooting](#troubleshooting)
6. [Emergency Procedures](#emergency-procedures)
7. [Maintenance](#maintenance)

## 🚀 Hızlı Başlangıç

### Gereksinimler Kontrolü

```bash
# Gerekli araçların yüklü olduğunu kontrol edin
make check-prerequisites

# Versiyonları kontrol edin
dotnet --version    # .NET 8.0+
python --version    # Python 3.11+
docker --version    # Docker 24.0+
kubectl version     # Kubernetes 1.28+
helm version        # Helm 3.12+
```

### İlk Kurulum

```bash
# Repository'yi klonlayın
git clone <repository-url>
cd opas

# Geliştirme ortamını hazırlayın
make setup

# Ortamı başlatın
make dev-up

# Sağlık kontrolü yapın
make health-check
```

## 🛠️ Geliştirme Ortamı

### Ortam Başlatma

```bash
# Tüm servisleri başlat
make dev-up

# Sadece belirli servisleri başlat
make dev-up service=auth-service,user-service

# Arka planda çalıştır
make dev-up background=true
```

### Ortam Durdurma

```bash
# Tüm servisleri durdur
make dev-down

# Sadece belirli servisleri durdur
make dev-down service=auth-service

# Verileri temizle
make dev-clean
```

### Log İzleme

```bash
# Tüm logları izle
make dev-logs

# Belirli servisin loglarını izle
make dev-logs service=auth-service

# Son 100 satır log
make dev-logs tail=100

# Hata loglarını filtrele
make dev-logs filter=error
```

### Test Çalıştırma

```bash
# Tüm testleri çalıştır
make test

# Belirli servisin testlerini çalıştır
make test-service service=user-service

# Integration testleri
make test-integration

# Performance testleri
make test-performance
```

## 🚀 Production Deployment

### Pre-deployment Checklist

- [ ] Tüm testler geçiyor
- [ ] Security scan tamamlandı
- [ ] Performance testleri geçiyor
- [ ] Database migration'ları hazır
- [ ] Configuration'lar güncellendi
- [ ] Monitoring alert'leri aktif

### Deployment Komutları

```bash
# Staging'e deploy
make deploy environment=staging

# Production'a deploy
make deploy environment=production

# Blue-green deployment
make deploy-blue-green

# Canary deployment
make deploy-canary percentage=10
```

### Rollback

```bash
# Son versiyona rollback
make rollback

# Belirli versiyona rollback
make rollback version=v1.2.3

# Emergency rollback
make rollback-emergency
```

## 📊 Monitoring & Alerting

### Health Checks

```bash
# Tüm servislerin sağlık durumu
make health-check

# Belirli servisin sağlık durumu
make health-check service=auth-service

# Detaylı sağlık raporu
make health-check detailed=true
```

### Metrics İzleme

```bash
# Prometheus metrics
make metrics

# Grafana dashboard'ları
make grafana-dashboards

# Custom metrics
make metrics custom=response-time,error-rate
```

### Log Analizi

```bash
# OpenSearch'te log arama
make logs search="error"

# Belirli zaman aralığında loglar
make logs time-range="last-1-hour"

# Log analizi raporu
make logs analyze=true
```

### Distributed Tracing

```bash
# Jaeger traces
make traces

# Belirli request'in trace'i
make traces request-id=abc123

# Performance analizi
make traces analyze=performance
```

## 🔧 Troubleshooting

### Servis Sorunları

#### Servis Başlamıyor

```bash
# Logları kontrol et
make dev-logs service=<service-name>

# Konfigürasyonu kontrol et
make config-check service=<service-name>

# Dependency'leri kontrol et
make dependency-check service=<service-name>
```

#### Servis Yavaş

```bash
# Performance metrics
make performance-check service=<service-name>

# Database connection pool
make db-connection-check service=<service-name>

# Memory usage
make memory-check service=<service-name>
```

#### Database Sorunları

```bash
# Connection test
make db-test

# Migration status
make db-migration-status

# Backup/restore
make db-backup
make db-restore file=backup.sql
```

### Network Sorunları

```bash
# Service discovery
make service-discovery

# Network connectivity
make network-test

# DNS resolution
make dns-test
```

### Event-Driven Sorunları

```bash
# Kafka cluster status
make kafka-status

# RabbitMQ status
make rabbitmq-status

# Dead letter queue
make dlq-check

# Outbox pattern status
make outbox-status
```

## 🚨 Emergency Procedures

### Servis Down

1. **Hızlı Değerlendirme**
   ```bash
   make emergency-assessment
   ```

2. **Rollback**
   ```bash
   make rollback-emergency
   ```

3. **Monitoring**
   ```bash
   make emergency-monitoring
   ```

### Database Down

1. **Failover**
   ```bash
   make db-failover
   ```

2. **Backup Restore**
   ```bash
   make db-emergency-restore
   ```

3. **Verification**
   ```bash
   make db-verify
   ```

### Security Incident

1. **Isolation**
   ```bash
   make security-isolate
   ```

2. **Investigation**
   ```bash
   make security-investigate
   ```

3. **Recovery**
   ```bash
   make security-recover
   ```

## 🔧 Maintenance

### Scheduled Maintenance

```bash
# Maintenance mode aktif et
make maintenance-on

# Maintenance mode deaktif et
make maintenance-off

# Maintenance status
make maintenance-status
```

### Database Maintenance

```bash
# Vacuum
make db-vacuum

# Reindex
make db-reindex

# Statistics update
make db-analyze
```

### Cache Maintenance

```bash
# Redis cache clear
make cache-clear

# Cache warmup
make cache-warmup

# Cache statistics
make cache-stats
```

### Log Rotation

```bash
# Log rotation
make log-rotate

# Log cleanup
make log-cleanup

# Log archive
make log-archive
```

## 📞 Emergency Contacts

### On-Call Schedule
- **Primary**: [İsim] - [Telefon] - [Email]
- **Secondary**: [İsim] - [Telefon] - [Email]
- **Escalation**: [İsim] - [Telefon] - [Email]

### External Dependencies
- **Cloud Provider**: [Provider] - [Support URL]
- **Database Provider**: [Provider] - [Support URL]
- **Monitoring Provider**: [Provider] - [Support URL]

---

**Son Güncelleme**: [Tarih]
**Versiyon**: 1.0.0
