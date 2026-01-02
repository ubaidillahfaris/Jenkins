.PHONY: help build up down restart logs shell clean status

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build Jenkins container
	docker-compose build

up: ## Start Jenkins container
	docker-compose up -d
	@echo "Jenkins is starting..."
	@echo "Access at: http://localhost/jenkins"
	@echo "Get initial password with: make password"

down: ## Stop and remove Jenkins container
	docker-compose down

restart: ## Restart Jenkins container
	docker-compose restart

logs: ## Show Jenkins logs (follow mode)
	docker-compose logs -f jenkins

shell: ## Open shell in Jenkins container
	docker exec -it jenkins bash

password: ## Get initial admin password
	@docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "Jenkins not ready yet or already configured"

status: ## Show container status
	docker-compose ps

clean: ## Remove container and volumes (WARNING: deletes all data!)
	@echo "WARNING: This will delete all Jenkins data!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		rm -rf jenkins_home/*; \
		echo "Jenkins data cleaned!"; \
	fi

backup: ## Backup Jenkins home directory
	@mkdir -p backups
	@tar -czf backups/jenkins_backup_$$(date +%Y%m%d_%H%M%S).tar.gz jenkins_home/
	@echo "Backup created in backups/"

docker-test: ## Test Docker access inside Jenkins container
	docker exec jenkins docker --version
	docker exec jenkins docker-compose --version
	docker exec jenkins docker ps
