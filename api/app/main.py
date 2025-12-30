import os
import time
import logging
from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse
import psycopg2
from psycopg2.extras import RealDictCursor

from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

APP_NAME = "seguridad-resiliencia-api"

DB_HOST = os.getenv("DB_HOST", "db")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "appdb")
DB_USER = os.getenv("DB_USER", "appuser")
DB_PASS = os.getenv("DB_PASS", "apppass")

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(APP_NAME)

app = FastAPI(title=APP_NAME)

REQ_COUNT = Counter("http_requests_total", "Total de requests HTTP", ["method", "path", "status"])
REQ_LAT = Histogram("http_request_duration_seconds", "Latencia de requests HTTP", ["path"])
LOGIN_FAIL = Counter("login_failed_total", "Total de logins fallidos")

def db_query_one():
    conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT,
        dbname=DB_NAME, user=DB_USER, password=DB_PASS,
        connect_timeout=1,
    )
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # evita colgarse si la DB está “congelada”
            cur.execute("SET statement_timeout = 800;")  # ms
            cur.execute("SELECT now() as now;")
            return cur.fetchone()
    finally:
        conn.close()

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    path = request.url.path
    start = time.time()
    status_code = 500
    try:
        response = await call_next(request)
        status_code = response.status_code
        return response
    finally:
        elapsed = time.time() - start
        REQ_LAT.labels(path=path).observe(elapsed)
        REQ_COUNT.labels(method=request.method, path=path, status=str(status_code)).inc()

@app.get("/estado")
def estado():
    return {"servicio": "ok", "app": APP_NAME}

@app.post("/login")
async def login(payload: dict):
    user = payload.get("user", "")
    password = payload.get("password", "")
    if user == "admin" and password == "admin":
        return {"ok": True, "msg": "login correcto (demo)"}
    LOGIN_FAIL.inc()
    return JSONResponse(status_code=401, content={"ok": False, "msg": "credenciales inválidas"})

@app.get("/datos")
def datos():
    try:
        row = db_query_one()
        return {"ok": True, "db_time": str(row["now"])}
    except Exception as e:
        # log interno para diagnóstico
        log.warning("DB no disponible: %s", repr(e))
        # respuesta “segura” al cliente
        return JSONResponse(
            status_code=503,
            content={"ok": False, "modo": "degradado", "razon": "db_no_disponible"}
        )

@app.get("/metrics")
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/")
def root():
    return {"app": APP_NAME, "rutas": ["/estado", "/login", "/datos", "/metrics"]}


@app.get("/live")
def live():
    return {"servicio": "ok", "tipo": "liveness"}

@app.get("/ready")
def ready():
    try:
        row = db_query_one()
        return {"servicio": "ok", "tipo": "readiness", "db_time": str(row["now"])}
    except Exception as e:
        log.warning("Readiness FAIL (DB no disponible): %s", repr(e))
        return JSONResponse(status_code=503, content={"servicio": "fail", "tipo": "readiness", "razon": "db_no_disponible"})

