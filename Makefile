.PHONY: render up down restart logs ps demo test check

render:
	./monitoring/alertmanager/render_alertmanager.sh

up: render
	docker compose up -d --build

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f --tail=120

ps:
	docker compose ps

demo:
	./evidencias/demo_all.sh

# Tests de la API (necesita Python 3.12+)
test:
	cd api && python -m pip install -q -r requirements-dev.txt && python -m pytest -q

# Valida la configuración de Docker Compose y las reglas de Prometheus
check:
	docker compose config --quiet
	docker run --rm -v "$(PWD)/monitoring/prometheus:/p" --entrypoint promtool prom/prometheus:v2.55.1 check rules /p/rules/alerts.yml /p/rules/alerts.prod.yml
