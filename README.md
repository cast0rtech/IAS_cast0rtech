# EMA Alarm Management and Telemetry

An extensible local middleware application for alarm points, a floor-plan dashboard, and optional hardware integrations. EMA runs on the host OS or in Docker and owns the integration logic. LOGO!, Yeastar, and other devices connect independently to EMA; they do not communicate directly with each other. All developer documentation is in English. The dashboard supports English, German, and Spanish.

## Quick start

Requirements: Docker Engine and Docker Compose v2.

1. Copy `.env.example` to `.env` and adjust settings if needed.
2. Start the stack: `docker compose up --build -d`.
3. Open `http://localhost:8080`.
4. The API documentation is at `http://localhost:8000/docs`.

The initial installation runs in **simulation mode**. It does not connect to or control real hardware, place calls, or trigger emergency outputs. Read [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) before enabling integrations.

## Components

- `backend/`: FastAPI API, SQLite persistence, WebSocket updates, configurable FC01–FC04 Modbus TCP polling adapter, unit tests.
- `frontend/`: floor-plan editor and live dashboard with English, German, and Spanish translations.
- `rpi/`: Raspberry Pi deployment tools:
  - `rpi/alpine/`: **EMA Industrial Alpine OS** (standalone 100% RAM diskless OS, 3s boot, immune to power-cut corruption, see [docs/ALPINE_EMA_OS.md](docs/ALPINE_EMA_OS.md)).
  - `rpi/setup.sh`: Automated provisioning suite for Raspberry Pi OS (systemd units, watchdog, kiosk mode, cloud-init).
- `alarme.csv`: sample alarm-to-phone/TTS mapping (sample data only).
- `telephony/asterisk/`: opt-in Asterisk/PJSIP configuration template for TTS calls through a Yeastar TG400.
- `docs/`: Architecture, deployment, and integration notes ([docs/ALPINE_EMA_OS.md](docs/ALPINE_EMA_OS.md), [docs/OFFLINE_AIRGAP_GUIDE.md](docs/OFFLINE_AIRGAP_GUIDE.md), and [docs/RASPBERRY_PI_OS.md](docs/RASPBERRY_PI_OS.md)).

## Current integration boundary

Modbus reads are opt-in and read-only. Each Modbus point can have its own host/IP, port 502–510, function code, address, and unit ID. Outbound calling and local TTS have an opt-in Asterisk/espeak-ng implementation template; it needs TG400-specific SIP configuration and commissioning. GPIO/USB relays, call outcome retries, and emergency Modbus writes remain unimplemented.
