# OPAS - Microservices Platform Makefile
# Modern microservices platform with event-driven architecture

.PHONY: help setup dev-up dev-down dev-logs test deploy health-check

# Default target
help:
	@echo "OPAS Microservices Platform - Available Commands:"
	@echo ""
	@echo "Development:"
	@echo "  setup           - Setup development environment"
	@echo "  dev-up          - Start development environment"
	@echo "  dev-down        - Stop development environment"
	@echo "  dev-logs        - View development logs"
	@echo "  dev-clean       - Clean development data"
	@echo ""
	@echo "Testing:"
	@echo "  test            - Run all tests"
	@echo "  test-service    - Run tests for specific service"
	@echo "  test-integration- Run integration tests"
	@echo "  test-performance- Run performance tests"
	@echo ""
	@echo "Deployment:"
	@echo "  deploy          - Deploy to environment"
	@echo "  rollback        - Rollback deployment"
	@echo "  health-check    - Check service health"
	@echo ""
	@echo "Monitoring:"
	@echo "  logs            - View application logs"
	@echo "  metrics         - View metrics"
	@echo "  traces          - View distributed traces"
	@echo ""
	@echo "Security:"
	@echo "  security-scan   - Run security scans"
	@echo "  security-audit  - Run security audit"
	@echo ""
	@echo "Maintenance:"
	@echo "  maintenance-on  - Enable maintenance mode"
	@echo "  maintenance-off - Disable maintenance mode"
	@echo "  backup          - Create backup"
	@echo "  restore         - Restore from backup"

# Variables
DOCKER_COMPOSE_FILE = docker-compose.yml
KUBERNETES_NAMESPACE = opas
ENVIRONMENT ?= development

# Development Environment
setup:
	@echo "Setting up OPAS development environment..."
	@echo "Checking prerequisites..."
	@command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed. Aborting." >&2; exit 1; }
	@command -v dotnet >/dev/null 2>&1 || { echo ".NET 8 SDK is required but not installed. Aborting." >&2; exit 1; }
	@command -v python3 >/dev/null 2>&1 || { echo "Python 3.11+ is required but not installed. Aborting." >&2; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Aborting." >&2; exit 1; }
	@command -v helm >/dev/null 2>&1 || { echo "Helm is required but not installed. Aborting." >&2; exit 1; }
	@echo "Prerequisites check passed."
	@echo "Creating necessary directories..."
	@mkdir -p apps libs platform proto openapi .github/workflows
	@echo "Setting up Docker networks..."
	@docker network create opas-network 2>/dev/null || true
	@echo "Setup completed successfully!"

# Development Environment
up:
	@echo "Starting OPAS development environment..."
	@if [ ! -f "platform/.env.dev" ]; then \
		echo "Creating .env.dev from sample..."; \
		cp platform/.env.dev.sample platform/.env.dev; \
	fi
	@docker compose -f platform/docker-compose.dev.yaml --env-file platform/.env.dev up -d
	@echo "Development environment started!"
	@echo ""
	@echo "🌐 Development Stack URLs:"
	@echo "  Grafana: http://localhost:3000 (admin/admin)"
	@echo "  Jaeger: http://localhost:16686"
	@echo "  Redpanda Console: http://localhost:8080"
	@echo "  RabbitMQ Mgmt: http://localhost:15672 (opas/opas123)"
	@echo "  OpenSearch Dashboards: http://localhost:5601 (admin/admin123)"
	@echo "  MinIO Console: http://localhost:9001 (opas/opas12345)"
	@echo "  EMQX Dashboard: http://localhost:18083 (admin/public)"
	@echo "  Temporal UI: http://localhost:8233"
	@echo "  Kong Admin: http://localhost:8001"
	@echo "  Vault: http://localhost:8200 (dev-root)"

down:
	@echo "Stopping OPAS development environment..."
	@docker compose -f platform/docker-compose.dev.yaml down -v
	@echo "Development environment stopped!"

logs:
	@echo "Viewing development logs..."
	@docker compose -f platform/docker-compose.dev.yaml logs -f --tail 200

dev-up: up
dev-down: down
dev-logs: logs

dev-clean:
	@echo "Cleaning development data..."
	@docker system prune -f
	@docker volume prune -f
	@echo "Development data cleaned!"

# Gateway Management
gateway-parse:
	@docker compose -f platform/docker-compose.dev.yaml --env-file platform/.env.dev.sample exec -T kong \
		kong config parse /var/lib/kong/kong.yml && echo "Kong config parse: OK"

gateway-reload:
	@docker compose -f platform/docker-compose.dev.yaml --env-file platform/.env.dev.sample restart kong && \
	echo "Kong reloaded."

# Event Bus Management
bus-bootstrap:
	@echo "== Redpanda topics =="
	@bash platform/redpanda/bootstrap-topics.sh || pwsh platform/redpanda/bootstrap-topics.ps1
	@echo "== RabbitMQ definitions (restart to load) =="
	@docker compose -f platform/docker-compose.dev.yaml --env-file platform/.env.dev.sample restart rabbitmq

bus-status:
	@echo "-- Redpanda topics --"
	@docker compose -f platform/docker-compose.dev.yaml --env-file platform/.env.dev.sample exec -T redpanda rpk topic list
	@echo "-- RabbitMQ queues --"
	@curl -s -u $${RABBITMQ_DEFAULT_USER}:$${RABBITMQ_DEFAULT_PASS} http://localhost:15672/api/queues/opas-dev | jq '.[].name'

bus-reset:
	@echo "!! Dev only: purge queues and recreate topics"
	@docker compose -f platform/docker-compose.dev.yaml --env-file platform/.env.dev.sample exec -T redpanda rpk topic delete -r opas. -f || true
	@bash platform/redpanda/bootstrap-topics.sh || pwsh platform/redpanda/bootstrap-topics.ps1

# Frontend Development
web-dev:
	@echo "Starting web admin development server..."
	@cd apps/web-admin && pnpm install && pnpm dev

web-dev-mock:
	@echo "Starting web admin with MSW..."
	@cd apps/web-admin && pnpm install && NEXT_PUBLIC_ENABLE_MSW=true pnpm dev

web-build:
	@echo "Building web admin..."
	@cd apps/web-admin && pnpm install && pnpm build

# Windows-compatible commands
web-dev-win:
	@echo "Starting web admin development server (Windows)..."
	@cd apps\web-admin && pnpm install && pnpm dev

web-dev-mock-win:
	@echo "Starting web admin with MSW (Windows)..."
	@cd apps\web-admin && pnpm install && set NEXT_PUBLIC_ENABLE_MSW=true && pnpm dev

web-build-win:
	@echo "Building web admin (Windows)..."
	@cd apps\web-admin && pnpm install && pnpm build

# Testing
test:
	@echo "Running all tests..."
	@echo "Running .NET tests..."
	@find apps -name "*.csproj" -execdir dotnet test {} \;
	@echo "Running Python tests..."
	@find apps -name "requirements.txt" -execdir python -m pytest {} \;
	@echo "All tests completed!"

test-service:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Error: SERVICE parameter is required. Usage: make test-service SERVICE=service-name"; \
		exit 1; \
	fi
	@echo "Running tests for service: $(SERVICE)"
	@if [ -d "apps/$(SERVICE)" ]; then \
		if [ -f "apps/$(SERVICE)/*.csproj" ]; then \
			dotnet test apps/$(SERVICE); \
		elif [ -f "apps/$(SERVICE)/requirements.txt" ]; then \
			cd apps/$(SERVICE) && python -m pytest; \
		else \
			echo "No test configuration found for service $(SERVICE)"; \
		fi; \
	else \
		echo "Service $(SERVICE) not found in apps directory"; \
	fi

test-integration:
	@echo "Running integration tests..."
	@echo "Starting test environment..."
	@docker-compose -f docker-compose.test.yml up -d
	@echo "Running integration tests..."
	@dotnet test tests/Integration/
	@echo "Cleaning up test environment..."
	@docker-compose -f docker-compose.test.yml down
	@echo "Integration tests completed!"

test-performance:
	@echo "Running performance tests..."
	@echo "Starting performance test environment..."
	@docker-compose -f docker-compose.perf.yml up -d
	@echo "Running performance tests..."
	@dotnet test tests/Performance/
	@echo "Cleaning up performance test environment..."
	@docker-compose -f docker-compose.perf.yml down
	@echo "Performance tests completed!"

# Deployment
deploy:
	@if [ -z "$(ENVIRONMENT)" ]; then \
		echo "Error: ENVIRONMENT parameter is required. Usage: make deploy ENVIRONMENT=production"; \
		exit 1; \
	fi
	@echo "Deploying to $(ENVIRONMENT) environment..."
	@echo "Building Docker images..."
	@docker-compose build
	@echo "Pushing images to registry..."
	@docker-compose push
	@echo "Deploying to Kubernetes..."
	@helm upgrade --install opas platform/helm/opas --namespace $(KUBERNETES_NAMESPACE) --values platform/helm/opas/values-$(ENVIRONMENT).yml
	@echo "Deployment completed!"

rollback:
	@if [ -z "$(VERSION)" ]; then \
		echo "Rolling back to previous version..."; \
		helm rollback opas --namespace $(KUBERNETES_NAMESPACE); \
	else \
		echo "Rolling back to version $(VERSION)..."; \
		helm rollback opas $(VERSION) --namespace $(KUBERNETES_NAMESPACE); \
	fi
	@echo "Rollback completed!"

rollback-emergency:
	@echo "Emergency rollback initiated..."
	@helm rollback opas --namespace $(KUBERNETES_NAMESPACE) --timeout 5m
	@echo "Emergency rollback completed!"

# Health Checks
health-check:
	@echo "Checking service health..."
	@if [ "$(SERVICE)" ]; then \
		echo "Checking health for service: $(SERVICE)"; \
		curl -f http://localhost:8080/health/$(SERVICE) || echo "Service $(SERVICE) is not healthy"; \
	else \
		echo "Checking all services health..."; \
		curl -f http://localhost:8080/health || echo "Health check failed"; \
	fi

health-check-detailed:
	@echo "Running detailed health check..."
	@curl -s http://localhost:8080/health/detailed | jq '.'

# Monitoring
logs:
	@echo "Viewing application logs..."
	@if [ "$(SEARCH)" ]; then \
		echo "Searching logs for: $(SEARCH)"; \
		kubectl logs -n $(KUBERNETES_NAMESPACE) -l app=opas --tail=100 | grep "$(SEARCH)"; \
	else \
		kubectl logs -n $(KUBERNETES_NAMESPACE) -l app=opas --tail=100 -f; \
	fi

metrics:
	@echo "Viewing metrics..."
	@echo "Prometheus metrics endpoint: http://localhost:9090"
	@echo "Grafana dashboard: http://localhost:3000"
	@if [ "$(CUSTOM)" ]; then \
		echo "Custom metrics: $(CUSTOM)"; \
		curl -s http://localhost:9090/api/v1/query?query=$(CUSTOM) | jq '.'; \
	fi

traces:
	@echo "Viewing distributed traces..."
	@echo "Jaeger UI: http://localhost:16686"
	@if [ "$(REQUEST_ID)" ]; then \
		echo "Searching for request ID: $(REQUEST_ID)"; \
		curl -s "http://localhost:16686/api/traces?service=opas&operation=GET&tags=%7B%22http.request_id%22%3A%22$(REQUEST_ID)%22%7D" | jq '.'; \
	fi

# Security
security-scan:
	@echo "Running security scans..."
	@echo "Scanning Docker images..."
	@docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image opas:latest
	@echo "Scanning dependencies..."
	@dotnet list package --vulnerable
	@echo "Security scan completed!"

security-sast:
	@echo "Running SAST (Static Application Security Testing)..."
	@dotnet tool install --global dotnet-sonarscanner
	@dotnet sonarscanner begin /k:"opas" /d:sonar.host.url="http://localhost:9000"
	@dotnet build
	@dotnet sonarscanner end /d:sonar.login="admin"

security-dast:
	@echo "Running DAST (Dynamic Application Security Testing)..."
	@echo "Starting OWASP ZAP scan..."
	@docker run -v $(PWD):/zap/wrk/:rw -t owasp/zap2docker-stable zap-baseline.py -t http://localhost:8080

security-scan-containers:
	@echo "Scanning containers for vulnerabilities..."
	@docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity HIGH,CRITICAL opas:latest

security-scan-dependencies:
	@echo "Scanning dependencies for vulnerabilities..."
	@dotnet list package --vulnerable
	@pip-audit

# Maintenance
maintenance-on:
	@echo "Enabling maintenance mode..."
	@kubectl patch deployment opas-api-gateway -n $(KUBERNETES_NAMESPACE) -p '{"spec":{"replicas":0}}'
	@echo "Maintenance mode enabled!"

maintenance-off:
	@echo "Disabling maintenance mode..."
	@kubectl patch deployment opas-api-gateway -n $(KUBERNETES_NAMESPACE) -p '{"spec":{"replicas":3}}'
	@echo "Maintenance mode disabled!"

maintenance-status:
	@echo "Checking maintenance status..."
	@kubectl get deployment opas-api-gateway -n $(KUBERNETES_NAMESPACE) -o jsonpath='{.spec.replicas}'

backup:
	@echo "Creating backup..."
	@echo "Backing up databases..."
	@docker exec opas-postgres pg_dumpall -U postgres > backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "Backing up configurations..."
	@tar -czf config_backup_$(shell date +%Y%m%d_%H%M%S).tar.gz platform/
	@echo "Backup completed!"

restore:
	@if [ -z "$(FILE)" ]; then \
		echo "Error: FILE parameter is required. Usage: make restore FILE=backup.sql"; \
		exit 1; \
	fi
	@echo "Restoring from backup: $(FILE)"
	@docker exec -i opas-postgres psql -U postgres < $(FILE)
	@echo "Restore completed!"

# Database operations
db-test:
	@echo "Testing database connections..."
	@docker exec opas-postgres pg_isready -U postgres
	@echo "Database connection test completed!"

db-migration-status:
	@echo "Checking database migration status..."
	@docker exec opas-postgres psql -U postgres -c "SELECT * FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 10;"

db-backup:
	@echo "Creating database backup..."
	@docker exec opas-postgres pg_dumpall -U postgres > db_backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "Database backup completed!"

db-restore:
	@if [ -z "$(FILE)" ]; then \
		echo "Error: FILE parameter is required. Usage: make db-restore FILE=backup.sql"; \
		exit 1; \
	fi
	@echo "Restoring database from: $(FILE)"
	@docker exec -i opas-postgres psql -U postgres < $(FILE)
	@echo "Database restore completed!"

# Cache operations
cache-clear:
	@echo "Clearing Redis cache..."
	@docker exec opas-redis redis-cli FLUSHALL
	@echo "Cache cleared!"

cache-warmup:
	@echo "Warming up cache..."
	@curl -X POST http://localhost:8080/api/v1/cache/warmup
	@echo "Cache warmup completed!"

cache-stats:
	@echo "Cache statistics..."
	@docker exec opas-redis redis-cli INFO memory

# Log operations
log-rotate:
	@echo "Rotating logs..."
	@docker exec opas-fluentd fluentd-ctl rotate
	@echo "Log rotation completed!"

log-cleanup:
	@echo "Cleaning up old logs..."
	@find /var/log/opas -name "*.log.*" -mtime +7 -delete
	@echo "Log cleanup completed!"

log-archive:
	@echo "Archiving logs..."
	@tar -czf logs_archive_$(shell date +%Y%m%d_%H%M%S).tar.gz /var/log/opas
	@echo "Log archive completed!"

# Service creation
create-service:
	@if [ -z "$(NAME)" ]; then \
		echo "Error: NAME parameter is required. Usage: make create-service NAME=my-service TYPE=dotnet"; \
		exit 1; \
	fi
	@if [ -z "$(TYPE)" ]; then \
		echo "Error: TYPE parameter is required. Usage: make create-service NAME=my-service TYPE=dotnet"; \
		exit 1; \
	fi
	@echo "Creating service: $(NAME) of type: $(TYPE)"
	@mkdir -p apps/$(NAME)
	@if [ "$(TYPE)" = "dotnet" ]; then \
		dotnet new webapi -n $(NAME) -o apps/$(NAME); \
		echo "Created .NET service: $(NAME)"; \
	elif [ "$(TYPE)" = "python" ]; then \
		mkdir -p apps/$(NAME)/src apps/$(NAME)/tests; \
		touch apps/$(NAME)/requirements.txt apps/$(NAME)/Dockerfile apps/$(NAME)/src/__init__.py; \
		echo "Created Python service: $(NAME)"; \
	else \
		echo "Unsupported service type: $(TYPE). Supported types: dotnet, python"; \
		exit 1; \
	fi
	@echo "Service $(NAME) created successfully!"

# Prerequisites check
check-prerequisites:
	@echo "Checking prerequisites..."
	@command -v docker >/dev/null 2>&1 && echo "✓ Docker installed" || echo "✗ Docker not installed"
	@command -v dotnet >/dev/null 2>&1 && echo "✓ .NET SDK installed" || echo "✗ .NET SDK not installed"
	@command -v python3 >/dev/null 2>&1 && echo "✓ Python 3 installed" || echo "✗ Python 3 not installed"
	@command -v kubectl >/dev/null 2>&1 && echo "✓ kubectl installed" || echo "✗ kubectl not installed"
	@command -v helm >/dev/null 2>&1 && echo "✓ Helm installed" || echo "✗ Helm not installed"
	@command -v jq >/dev/null 2>&1 && echo "✓ jq installed" || echo "✗ jq not installed"

# Clean
clean:
	@echo "Cleaning project..."
	@find . -name "bin" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "obj" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.pyc" -delete 2>/dev/null || true
	@echo "Clean completed!"

# Version info
version:
	@echo "OPAS Microservices Platform"
	@echo "Version: 1.0.0"
	@echo "Build Date: $(shell date)"
	@echo "Git Commit: $(shell git rev-parse HEAD 2>/dev/null || echo 'unknown')"
