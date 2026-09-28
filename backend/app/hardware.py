"""Read-only Modbus polling adapter. GPIO, USB relay and output writes are intentionally unimplemented."""
import asyncio
import logging
from sqlmodel import Session, select
from pymodbus.client import AsyncModbusTcpClient
from .config import MODBUS_ENABLED, MODBUS_HOST, MODBUS_PORT, MODBUS_UNIT_ID, MODBUS_POLL_SECONDS
from .database import engine
from .hub import hub
from .models import DataPoint
from .notifications import safe_dispatch_alarm

log = logging.getLogger(__name__)


async def poll_modbus(stop: asyncio.Event):
    if not MODBUS_ENABLED:
        log.info("Modbus polling disabled (or simulation mode enabled)")
        return
    clients: dict[tuple[str, int], AsyncModbusTcpClient] = {}
    try:
        while not stop.is_set():
            try:
                with Session(engine) as session:
                    points = session.exec(select(DataPoint).where(DataPoint.source_type == "modbus")).all()
                    for point in points:
                        host = point.host.strip() or MODBUS_HOST
                        port = point.port if point.port else MODBUS_PORT
                        key = (host, port)
                        client = clients.get(key)
                        if client is None:
                            client = AsyncModbusTcpClient(host, port=port, timeout=2)
                            clients[key] = client
                        if not client.connected:
                            await client.connect()
                        if not client.connected:
                            continue
                        # Addresses are decimal, zero-based Modbus PDU offsets.
                        try:
                            raw_address = point.address.strip().upper()
                            address = int(raw_address[1:]) - 1 if raw_address.startswith("M") and raw_address[1:].isdigit() else int(raw_address)
                            if address < 0 or address > 65535:
                                continue
                        except ValueError:
                            log.warning("Invalid address %r for point %s", point.address, point.id)
                            continue
                        fc = point.function_code
                        if fc == 1:
                            result = await client.read_coils(address, count=1, slave=point.unit_id)
                            value = bool(result.bits[0]) if not result.isError() else None
                        elif fc == 2:
                            result = await client.read_discrete_inputs(address, count=1, slave=point.unit_id)
                            value = bool(result.bits[0]) if not result.isError() else None
                        elif fc == 3:
                            result = await client.read_holding_registers(address, count=1, slave=point.unit_id)
                            value = (int(result.registers[0]) == 1) if not result.isError() else None
                        else:  # FC04
                            result = await client.read_input_registers(address, count=1, slave=point.unit_id)
                            value = (int(result.registers[0]) == 1) if not result.isError() else None
                        if value is not None and value != point.state:
                            point.state = value
                            session.add(point)
                            session.commit()
                            await hub.publish({"type": "point.updated", "point": point.model_dump()})
                            if value:
                                asyncio.create_task(safe_dispatch_alarm(point.address, str(point.id)))
            except Exception:
                log.exception("Modbus polling cycle failed")
            try:
                await asyncio.wait_for(stop.wait(), timeout=MODBUS_POLL_SECONDS)
            except asyncio.TimeoutError:
                pass
    finally:
        for client in clients.values():
            client.close()
