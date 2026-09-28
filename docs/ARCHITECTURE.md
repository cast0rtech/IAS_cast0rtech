# Architecture

## Scope

EMA is the central middleware and local alarm-point dashboard. LOGO!, Yeastar, and other equipment connect to EMA independently; the devices do not communicate directly with one another. The initial version provides a FastAPI service, SQLite persistence, a browser-based floor-plan editor, WebSocket event delivery, and an opt-in read-only Modbus TCP polling adapter.

## Services

- **Frontend:** static HTML, CSS, and JavaScript served by Nginx on port 8080. The UI is translated into English, German, and Spanish. The selected language and floor-plan image are stored in browser local storage.
- **Backend:** FastAPI on port 8000. REST endpoints manage data points; `/ws` streams create, update, and delete events.
- **Database:** SQLite database persisted in the `ema-data` Docker volume.
- **Modbus adapter:** polls configured Modbus points only when simulation mode is disabled and Modbus is enabled. Each point has a host/IP, port (502–510), function code (FC01–FC04), zero-based register/bit address, and unit ID. FC01 reads coils, FC02 discrete inputs, FC03 holding registers, and FC04 input registers. For FC03/FC04, only integer value 1 is ON; 0 is OFF. Confirm this interpretation and address convention against the device configuration.
- **Calling/TTS:** on an active point transition, EMA optionally matches `alarme.csv`, synthesizes speech locally with `espeak-ng`, and asks Asterisk to originate over AMI. Asterisk sends SIP through the Yeastar TG400 gateway and plays the WAV after answer. Calling is disabled by default. See [CALLING_AND_TTS.md](CALLING_AND_TTS.md).

## Data model

Each data point has an integer ID, name, source type (`modbus`, `gpio`, `usb`), address, Modbus host/port/function code/unit ID, floor-plan x/y coordinates (0–100 percent), and Boolean state. The REST API is rooted at `/api/points` and supports GET, POST, PUT/PATCH, and DELETE. WebSocket events are JSON objects with `type` and, where applicable, `point` fields.

## Safety boundary

Simulation is enabled by default. GPIO reads, USB relay control, Modbus writes, and call outcome/retry tracking are not implemented. SIP/TTS dispatch is an opt-in template integration, not commissioned gateway configuration. Alarm output behavior requires an approved, equipment-specific design, explicit timeout and retry rules, and commissioning with the responsible site engineer.
