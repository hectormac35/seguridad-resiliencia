import logging
import os
import secrets
import time

import psycopg2
from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel

APP_NAME = "seguridad-resiliencia-api"

# Conexión a la base de datos: DATABASE_URL (la que pasa docker-compose) o, si no existe, DB_*
DATABASE_URL = os.getenv("DATABASE_URL")
DB_PARAMS = {
    "host": os.getenv("DB_HOST", "db"),
    "port": int(os.getenv("DB_PORT", "5432")),
    "dbname": os.getenv("DB_NAME", "appdb"),
    "user": os.getenv("DB_USER", "appuser"),
    "password": os.getenv("DB_PASS", ""),
}

# Credenciales de la demo de login (configurables por entorno)
DEMO_USER = os.getenv("DEMO_USER", "admin")
DEMO_PASSWORD = os.getenv("DEMO_PASSWORD", "admin")

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(APP_NAME)

app = FastAPI(title=APP_NAME)

REQ_COUNT = Counter("http_requests_total", "Total de requests HTTP", ["method", "path", "status"])
REQ_LAT = Histogram("http_request_duration_seconds", "Latencia de requests HTTP", ["path"])
LOGIN_FAIL = Counter("login_failed_total", "Total de logins fallidos")


def db_query_one():
    """Consulta mínima a la BD con timeouts cortos para no colgarse si está caída o congelada."""
    if DATABASE_URL:
        conn = psycopg2.connect(DATABASE_URL, connect_timeout=1)
    else:
        conn = psycopg2.connect(**DB_PARAMS, connect_timeout=1)
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SET statement_timeout = 800;")  # ms
            cur.execute("SELECT now() AS now;")
            return cur.fetchone()
    finally:
        conn.close()


def route_label(request: Request) -> str:
    """Etiqueta de ruta para las métricas.

    Usa la plantilla de la ruta y agrupa las desconocidas en "otras": si se usara la URL tal cual,
    cualquiera podría crear miles de series en Prometheus pidiendo URLs inventadas.
    """
    route = request.scope.get("route")
    return getattr(route, "path", None) or "otras"


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = time.perf_counter()
    status_code = 500
    try:
        response = await call_next(request)
        status_code = response.status_code
        return response
    finally:
        path = route_label(request)
        REQ_LAT.labels(path=path).observe(time.perf_counter() - start)
        REQ_COUNT.labels(method=request.method, path=path, status=str(status_code)).inc()


@app.get("/")
def root():
    return {"app": APP_NAME, "rutas": ["/estado", "/live", "/ready", "/login", "/datos", "/metrics"]}


@app.get("/estado")
def estado():
    return {"servicio": "ok", "app": APP_NAME}


@app.get("/live")
def live():
    """Liveness: el proceso responde (no depende de la BD)."""
    return {"servicio": "ok", "tipo": "liveness"}


@app.get("/ready")
def ready():
    """Readiness: además, la BD está disponible."""
    try:
        row = db_query_one()
        return {"servicio": "ok", "tipo": "readiness", "db_time": str(row["now"])}
    except Exception as e:
        log.warning("Readiness FAIL (DB no disponible): %r", e)
        return JSONResponse(
            status_code=503,
            content={"servicio": "fail", "tipo": "readiness", "razon": "db_no_disponible"},
        )


class LoginRequest(BaseModel):
    user: str = ""
    password: str = ""


@app.post("/login")
def login(payload: LoginRequest):
    # compare_digest: el tiempo de respuesta no depende de cuántos caracteres coinciden
    ok_user = secrets.compare_digest(payload.user.encode(), DEMO_USER.encode())
    ok_pass = secrets.compare_digest(payload.password.encode(), DEMO_PASSWORD.encode())
    if ok_user and ok_pass:
        return {"ok": True, "msg": "login correcto (demo)"}
    LOGIN_FAIL.inc()
    return JSONResponse(status_code=401, content={"ok": False, "msg": "credenciales inválidas"})


@app.get("/datos")
def datos():
    try:
        row = db_query_one()
        return {"ok": True, "db_time": str(row["now"])}
    except Exception as e:
        # Detalle solo en el log interno; al cliente, una respuesta "segura" en modo degradado
        log.warning("DB no disponible: %r", e)
        return JSONResponse(
            status_code=503,
            content={"ok": False, "modo": "degradado", "razon": "db_no_disponible"},
        )


@app.get("/metrics")
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)
