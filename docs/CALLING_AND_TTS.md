# Outbound alarm calls and TTS

## Design

EMA is the decision-making middleware. The LOGO!/Modbus side reports a point state to EMA; EMA looks up the alarm text and destination in `alarme.csv`, renders a local WAV prompt with `espeak-ng`, and requests an outbound call from Asterisk over AMI. Asterisk originates the SIP call through its `yeastar-tg400` PJSIP peer. When the called party answers, the Asterisk dialplan plays the prompt and hangs up. The TG400 is the SIP-to-mobile-network gateway; it does not decide alarm policy or synthesize speech. The endpoint devices do not communicate directly with one another.

```text
LOGO! --Modbus TCP--> EMA backend --AMI originate--> Asterisk --SIP trunk--> Yeastar TG400 --> phone network
                           |                           ^
                           +-- espeak-ng WAV ----------+
```

The TTS language is a per-row `TTS_Language` field in the semicolon-separated CSV (`de`, `en`, or `es`). `TTS_Text` is the spoken message; the dashboard language does not silently change an operator-approved alarm script.

## Configuration outline

1. Give the Asterisk host and TG400 a stable LAN address. Configure a SIP trunk on the TG400 that accepts calls from the Asterisk host and routes outbound calls through its cellular SIM channels.
2. Replace the example TG400 address in `telephony/asterisk/etc/asterisk/pjsip.conf` in both `contact` and `match`. Configure the TG400 routing policy, allowed caller IDs, codecs, SIM selection, and dial rules in its web administration UI.
3. Set a private `ASTERISK_AMI_SECRET` in `.env` and the matching `secret` in `manager.conf`. Restrict AMI to the private Docker/host network. Never expose port 5038 to the LAN or internet; Compose binds its host port to loopback.
4. Add a point's alarm row to `alarme.csv`. Numeric dashboard offsets are zero-based (offset 0 maps to CSV label `M1`); `M1` notation is also accepted and maps to offset 0.
5. Configure `.env` from the example, set `EMA_SIMULATION_MODE=false`, `EMA_MODBUS_ENABLED=true`, and only after bench commissioning set `EMA_CALLS_ENABLED=true`. Start with `docker compose --profile telephony up --build -d`.
6. Test with an authorized test number and non-production SIM, then inspect backend/Asterisk logs and the TG400 call history.

## Current implementation boundary

The backend contains an opt-in CSV lookup, `espeak-ng` file generation, and an Asterisk AMI Originate request. Asterisk has an example outbound dialplan and static TG400 peer configuration. Calls remain disabled by default. The sample Asterisk configuration and SIP route are templates and require matching changes in the TG400 UI and local network; they are not device commissioning data.

Call outcome tracking and retry/escalation behavior are not implemented yet. The initial project specification asks for a repeat counter for unanswered/busy calls during weekday evenings and weekends and a Modbus emergency output after two failures. This requires an AMI event listener or persisted Asterisk CDR integration, a timezone/business-hours policy, and a confirmed safe output map. That output is deliberately not written by this release.
