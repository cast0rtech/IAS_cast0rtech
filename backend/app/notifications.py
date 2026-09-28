"""Alarm-to-speech and Asterisk AMI dispatch. Outbound calls are opt-in."""
import asyncio
import csv
import logging
import os
import re
import uuid
from pathlib import Path

from .config import CSV_PATH

log = logging.getLogger(__name__)
CALLS_ENABLED = os.getenv("EMA_CALLS_ENABLED", "false").lower() in {"1", "true", "yes", "on"}
TTS_LANGUAGE = os.getenv("EMA_TTS_LANGUAGE", "de")
AMI_HOST = os.getenv("ASTERISK_AMI_HOST", "asterisk")
AMI_PORT = int(os.getenv("ASTERISK_AMI_PORT", "5038"))
AMI_USERNAME = os.getenv("ASTERISK_AMI_USERNAME", "ema")
AMI_SECRET = os.getenv("ASTERISK_AMI_SECRET", "")
AUDIO_DIR = Path("/var/lib/asterisk/sounds/ema")
NUMBER_RE = re.compile(r"^\+?[0-9]{6,20}$")


def alarm_map() -> dict[str, dict[str, str]]:
    with open(CSV_PATH, newline="", encoding="utf-8-sig") as stream:
        return {row["Register_Modbus"].strip(): row for row in csv.DictReader(stream, delimiter=";")}


def csv_key(register: str) -> str:
    normalized = register.strip().upper()
    if normalized.startswith("M") and normalized[1:].isdigit():
        return normalized
    if normalized.isdigit():
        return f"M{int(normalized) + 1}"
    return normalized


async def ami_action(fields: list[tuple[str, str]]) -> dict[str, str]:
    """Send one AMI action and return its immediate response (not final call outcome)."""
    if not AMI_SECRET:
        raise RuntimeError("ASTERISK_AMI_SECRET must be configured")
    reader, writer = await asyncio.wait_for(asyncio.open_connection(AMI_HOST, AMI_PORT), timeout=5)
    try:
        await asyncio.wait_for(reader.readline(), timeout=5)  # Asterisk AMI banner
        lines = ["Action: Login", f"Username: {AMI_USERNAME}", f"Secret: {AMI_SECRET}", "Events: off"]
        writer.write(("\r\n".join(lines) + "\r\n\r\n").encode())
        await writer.drain()
        response = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), timeout=5)
        if b"Response: Success" not in response:
            raise RuntimeError("Asterisk AMI login failed")
        writer.write(("\r\n".join(f"{k}: {v}" for k, v in fields) + "\r\n\r\n").encode())
        await writer.drain()
        response = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), timeout=8)
        return {line.split(":", 1)[0].strip(): line.split(":", 1)[1].strip()
                for line in response.decode(errors="replace").splitlines() if ":" in line}
    finally:
        writer.close()
        await writer.wait_closed()


async def dispatch_alarm(register: str, alarm_id: str) -> dict:
    """Generate localized speech and ask Asterisk to call via its TG400 SIP peer."""
    if not CALLS_ENABLED:
        return {"status": "disabled"}
    item = alarm_map().get(csv_key(register))
    if not item:
        log.warning("No alarm CSV entry for register %s", register)
        return {"status": "unmapped"}
    number = item["Destination_Number"].strip()
    if not NUMBER_RE.fullmatch(number):
        raise ValueError(f"Invalid destination number configured for {register}")
    prompt = uuid.uuid4().hex
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    voice = item.get("TTS_Language", TTS_LANGUAGE).strip() or TTS_LANGUAGE
    proc = await asyncio.create_subprocess_exec(
        "espeak-ng", "-v", voice, "-w", str(AUDIO_DIR / f"{prompt}.wav"), item["TTS_Text"].strip()
    )
    code = await proc.wait()
    if code != 0:
        raise RuntimeError("TTS audio generation failed")
    result = await ami_action([
        ("Action", "Originate"), ("Channel", f"PJSIP/{number}@yeastar-tg400"),
        ("Context", "ema-outbound"), ("Exten", number), ("Priority", "1"),
        ("Timeout", "45000"), ("Async", "true"), ("CallerID", "EMA Alarm"),
        ("Variable", f"EMA_PROMPT={prompt}"), ("Variable", f"EMA_ALARM_ID={alarm_id}"),
    ])
    return {"status": result.get("Response", "unknown").lower(), "prompt_id": prompt}


async def safe_dispatch_alarm(register: str, alarm_id: str) -> None:
    try:
        result = await dispatch_alarm(register, alarm_id)
        log.info("Alarm call request for %s: %s", alarm_id, result.get("status"))
    except Exception:
        log.exception("Alarm notification dispatch failed for point %s", alarm_id)
