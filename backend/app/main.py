import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from .config import SIMULATION_MODE
from .database import init_db
from .hardware import poll_modbus
from .hub import hub
from .routes import router


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    stop = asyncio.Event()
    task = asyncio.create_task(poll_modbus(stop))
    yield
    stop.set()
    await task


app = FastAPI(title="EMA Alarm Management API", version="0.1.0", lifespan=lifespan)
app.include_router(router)


@app.get("/api/health")
def health():
    return {"status": "ok", "simulation_mode": SIMULATION_MODE}


@app.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    await hub.connect(ws)
    try:
        while True:
            # Keep connection alive; clients may send a ping message.
            await ws.receive_text()
    except WebSocketDisconnect:
        hub.disconnect(ws)
