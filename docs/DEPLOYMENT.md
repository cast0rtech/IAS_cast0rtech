# Deployment

## Local development or test installation

1. Install Docker Engine and the Docker Compose v2 plugin.
2. Copy `.env.example` to `.env`.
3. Run `docker compose up --build -d` from the project root.
4. Open `http://<host-address>:8080`; API docs are at `http://<host-address>:8000/docs`.
5. Review logs with `docker compose logs -f` and stop with `docker compose down`.

The browser floor-plan image stays in that browser's local storage; it is not uploaded to the backend. Use a suitably sized image and keep a separate backup if it is operationally important.

## Raspberry Pi

Use a supported 64-bit Raspberry Pi OS Lite release and a wired Ethernet link where practical. Give the host a reserved address, restrict access to the dashboard/API at the network perimeter, and apply OS security updates. Confirm that the selected Docker images and Python dependencies support the target CPU architecture before deployment.

The compose file does not grant privileged access to the container. If a later hardware adapter needs GPIO or USB, map only its required device(s) and permissions. Never expose Modbus TCP or the API directly to the public internet.

## Enabling Modbus reads

Set `EMA_SIMULATION_MODE=false` and `EMA_MODBUS_ENABLED=true` in `.env`, then recreate the backend. For each Modbus point in the dashboard, configure its device IP/host, port (502–510), FC01/FC02/FC03/FC04, zero-based address, and unit ID. FC01 reads coils, FC02 discrete inputs, FC03 holding registers, and FC04 input registers. Bit functions map false/true to OFF/ON; register functions map exactly 0/1 to OFF/ON (other register values are treated as OFF). Verify address numbering, unit ID, active polarity, and device behavior before connecting a production system. The adapter performs reads only.

## Optional TTS and outbound calling

Outbound calls remain disabled unless `EMA_CALLS_ENABLED=true`. Before enabling, follow [CALLING_AND_TTS.md](CALLING_AND_TTS.md), update the Asterisk peer and manager credentials, configure the matching TG400 SIP trunk/outbound route and SIM, and test with an authorized number. Start the Asterisk container with `docker compose --profile telephony up --build -d`. The example static peer address and routing configuration are placeholders; a successful build does not verify SIP registration, audio/RTP reachability, or mobile call completion.

## Backups and upgrades

Back up the SQLite volume before upgrades. Stop the stack cleanly before copying its database file. Pin and review dependency/image updates as part of a maintenance process. Configure host-level UPS and orderly shutdown if power-loss resilience is required.
