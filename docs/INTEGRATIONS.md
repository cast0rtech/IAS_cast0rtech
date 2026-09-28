# Integration status and required decisions

This document distinguishes implemented behavior from hardware-specific work that still needs decisions and commissioning.

| Integration | Status | Information required before implementation |
|---|---|---|
| Modbus TCP | Optional, read-only FC01–FC04 polling adapter; per-point IP, port 502–510, address, and unit ID | LOGO! model/firmware, program address map and address numbering, unit ID, expected active polarity, and network topology |
| TTS and outbound calls | Opt-in `espeak-ng` TTS plus Asterisk AMI/PJSIP originate template through a TG400 peer | TG400 model/firmware and LAN IP, SIP trunk/auth mode, outbound route/SIM policy, network/RTP settings, approved caller ID, and test number |
| Local GPIO | Not implemented | Pi model, pin numbering scheme, electrical isolation, voltage levels, debounce, and safe state |
| USB relay | Not implemented | Exact module and protocol, serial device, channel map, pulse/latch behavior, watchdog, and safe state |
| SIP / Yeastar | Not implemented | Gateway model/firmware, supported API or SIP call method, account/network settings, call status source, and approved test destination |
| TTS / CSV dispatch | CSV sample only | Required encoding/delimiter, language per alarm, approved TTS engine, call schedule, and data protection requirements |
| Emergency output | Not implemented | Authorized cause-and-effect matrix, escalation policy, independent safety review, reset procedure, and explicit commissioning approval |

Do not wire this dashboard into a life-safety or security response path until the system has been reviewed and tested by qualified personnel. The web application is supervisory software, not a certified safety controller.
