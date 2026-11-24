"""Tests de la API sin base de datos real: db_query_one se sustituye en cada test."""
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient
from prometheus_client import REGISTRY

import app.main as main

client = TestClient(main.app)


@pytest.fixture
def db_ok(monkeypatch):
    monkeypatch.setattr(main, "db_query_one", lambda: {"now": datetime(2026, 1, 1, tzinfo=timezone.utc)})


@pytest.fixture
def db_caida(monkeypatch):
    def fallo():
        raise ConnectionError("could not connect to server: password=secreto host=db")
    monkeypatch.setattr(main, "db_query_one", fallo)


def metric(name: str, **labels) -> float:
    return REGISTRY.get_sample_value(name, labels) or 0.0


def test_liveness_no_depende_de_la_bd(db_caida):
    r = client.get("/live")
    assert r.status_code == 200
    assert r.json()["tipo"] == "liveness"


def test_readiness_ok(db_ok):
    assert client.get("/ready").status_code == 200


def test_readiness_falla_si_cae_la_bd(db_caida):
    r = client.get("/ready")
    assert r.status_code == 503
    assert r.json()["razon"] == "db_no_disponible"


def test_datos_modo_degradado_sin_filtrar_detalles(db_caida):
    r = client.get("/datos")
    assert r.status_code == 503
    assert r.json() == {"ok": False, "modo": "degradado", "razon": "db_no_disponible"}
    # El error interno (con datos de conexión) no llega al cliente
    assert "secreto" not in r.text and "password" not in r.text


def test_datos_ok(db_ok):
    r = client.get("/datos")
    assert r.status_code == 200
    assert r.json()["ok"] is True


def test_login_correcto():
    r = client.post("/login", json={"user": "admin", "password": "admin"})
    assert r.status_code == 200


def test_login_fallido_incrementa_metrica():
    antes = metric("login_failed_total")
    r = client.post("/login", json={"user": "admin", "password": "mala"})
    assert r.status_code == 401
    assert metric("login_failed_total") == antes + 1


def test_login_con_cuerpo_invalido_no_rompe():
    assert client.post("/login", content="no es json", headers={"content-type": "application/json"}).status_code == 422


def test_rutas_desconocidas_no_crean_series_nuevas():
    for i in range(5):
        client.get(f"/no-existe-{i}")
    texto = client.get("/metrics").text
    assert 'path="otras"' in texto
    assert "/no-existe-" not in texto


def test_metricas_usan_la_plantilla_de_la_ruta(db_ok):
    client.get("/datos")
    assert metric("http_requests_total", method="GET", path="/datos", status="200") >= 1


def test_database_url_tiene_prioridad(monkeypatch):
    llamadas = {}

    class FakeConn:
        def cursor(self, **_):
            class C:
                def __enter__(s): return s
                def __exit__(s, *a): pass
                def execute(s, *_): pass
                def fetchone(s): return {"now": "ahora"}
            return C()
        def close(self): pass

    def fake_connect(*args, **kwargs):
        llamadas["args"], llamadas["kwargs"] = args, kwargs
        return FakeConn()

    monkeypatch.setattr(main, "DATABASE_URL", "postgresql://u:p@db:5432/appdb")
    monkeypatch.setattr(main.psycopg2, "connect", fake_connect)
    assert main.db_query_one() == {"now": "ahora"}
    assert llamadas["args"] == ("postgresql://u:p@db:5432/appdb",)
