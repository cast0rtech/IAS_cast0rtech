import asyncio
from fastapi import WebSocket


class EventHub:
    def __init__(self):
        self.clients: set[WebSocket] = set()

    async def connect(self, ws: WebSocket):
        await ws.accept()
        self.clients.add(ws)

    def disconnect(self, ws: WebSocket):
        self.clients.discard(ws)

    async def publish(self, event: dict):
        stale = []
        for client in tuple(self.clients):
            try:
                await client.send_json(event)
            except Exception:
                stale.append(client)
        for client in stale:
            self.disconnect(client)


hub = EventHub()
