.PHONY: render up down restart logs ps demo

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
