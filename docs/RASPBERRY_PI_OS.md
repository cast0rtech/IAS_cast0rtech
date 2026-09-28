# Sistema Operativo y Appliance para Raspberry Pi (EMA Gateway)

Esta guía detalla la configuración y despliegue del sistema operativo **Raspberry Pi OS Lite (64 bits / Debian 12 Bookworm)** convertido en un **Appliance Industrial Dedicado** para el sistema EMA (Alarm Management & Telemetry).

---

## 1. Arquitectura del Appliance

El sistema está diseñado para operar 24/7 en entornos industriales (cuadros eléctricos, salas técnicas o subestaciones) junto a PLCs Siemens LOGO!, gateways VoIP Yeastar TG400 y redes Modbus TCP:

```
+-----------------------------------------------------------------------+
|                       Raspberry Pi OS Lite 64-bit                     |
|                                                                       |
|  +--------------------+  +--------------------+  +-----------------+  |
|  | Hardware Watchdog  |  |   Chrony (NTP)     |  |  UFW Firewall   |  |
|  |   (bcm2835_wdt)    |  | Sincronía alarmas  |  |  22 / 8080 / 502|  |
|  +--------------------+  +--------------------+  +-----------------+  |
|                                                                       |
|  +-----------------------------------------------------------------+  |
|  |                        Systemd Supervisors                      |  |
|  |  * ema.service (Docker Compose auto-start & restart)            |  |
|  |  * ema-watchdog.service (Health check continuo / autocuración)  |  |
|  |  * ema-kiosk.service (Opcional: Pantalla táctil HDMI Chromium)  |  |
|  +-----------------------------------------------------------------+  |
|                                                                       |
|  +-----------------------------------------------------------------+  |
|  |                     Docker Container Stack                      |  |
|  |  * Backend: FastAPI (Python 3.12, Modbus Poller, SQLite)        |  |
|  |  * Frontend: Nginx (Dashboard interactivo con planos)           |  |
|  |  * Telephony (Opt-in): Asterisk PJSIP + AMI + espeak-ng         |  |
|  +-----------------------------------------------------------------+  |
+-----------------------------------------------------------------------+
```

---

## 2. Métodos de Instalación

### Método 1: Aprovisionamiento Automatizado (Recomendado)

En una Raspberry Pi 3B+, 4, 5 o CM4 con **Raspberry Pi OS Lite (64-bit)** recién instalado:

1. Conéctate por SSH a la Raspberry Pi:
   ```bash
   ssh pi@<ip-de-tu-raspberry>
   ```

2. Clona el repositorio e inicia el instalador:
   ```bash
   git clone https://github.com/cast0rtech/IAS_cast0rtech.git /opt/ema
   cd /opt/ema
   sudo ./rpi/setup.sh
   ```

3. El script configurará automáticamente:
   - Repositorio oficial de Docker Engine y Compose v2.
   - Perro guardián por hardware (`bcm2835_wdt`) y `systemd` watchdog.
   - Sincronización horaria industrial con `chrony`.
   - Optimización de disco SD (swappiness baja, límites de logs para evitar desgaste).
   - Reglas de cortafuegos UFW (SSH en puerto 22, Dashboard en 8080).
   - Servicios systemd `ema.service` y `ema-watchdog.service`.

4. Abre en tu navegador:
   - Panel de control: `http://<ip-de-tu-raspberry>:8080`
   - Documentación API: `http://<ip-de-tu-raspberry>:8000/docs`

---

### Método 2: Instalación Desatendida con Raspberry Pi Imager (Cloud-Init)

Para flashear la tarjeta SD y que arranque completamente configurada sin teclado ni monitor:

1. Abre **Raspberry Pi Imager** en tu ordenador.
2. Selecciona **Raspberry Pi OS Lite (64-bit)**.
3. Copia el contenido de [rpi/cloud-init/user-data](file:///c:/Users/castor/Documents/GitHub/IAS_cast0rtech/rpi/cloud-init/user-data) y [rpi/cloud-init/network-config](file:///c:/Users/castor/Documents/GitHub/IAS_cast0rtech/rpi/cloud-init/network-config) en la partición `/boot/firmware/` de la SD recién grabada.
4. Inserta la SD en la Raspberry Pi y conecta el cable Ethernet. En el primer arranque, la Pi se aprovisionará automáticamente.

---

### Método 3: Modo Kiosk para Pantalla Táctil Industrial HDMI

Si tu Raspberry Pi tiene conectada una pantalla táctil oficial o monitor HDMI en el cuadro eléctrico:

```bash
sudo ./rpi/setup.sh --kiosk
```

Esto instalará un entorno gráfico mínimo y habilitará `ema-kiosk.service`, ejecutando Chromium en pantalla completa a `http://localhost:8080` con el cursor oculto.

---

## 3. Robustez Industrial y Protección de Tarjeta SD

### A. Protección contra Pérdida de Alimentación (OverlayFS / Read-Only)
Para evitar que cortes repentinos de energía corrompan la tarjeta SD, puedes activar el sistema de archivos de solo lectura con overlay en RAM oficial de Raspberry Pi:

```bash
sudo raspi-config
# Navega a: Performance Options -> Overlay File System -> Enable
```
> [!NOTE]
> Los datos de la base de datos SQLite se persisten en volúmenes Docker o en una partición montada de lectura/escritura (o memoria USB dedicada).

### B. Hardware Watchdog
El módulo `bcm2835_wdt` monitoriza el procesador a bajo nivel. Si el kernel o el sistema operativo se bloquean, la Raspberry Pi se reinicia automáticamente en 15 segundos sin intervención humana.

### C. Watchdog de Aplicación (`ema-watchdog.service`)
El script en [rpi/scripts/ema-watchdog.sh](file:///c:/Users/castor/Documents/GitHub/IAS_cast0rtech/rpi/scripts/ema-watchdog.sh) monitoriza periódicamente `/api/health` y el dashboard. Si los contenedores dejan de responder tras 3 intentos consecutivos, reinicia automáticamente la pila Docker y registra el evento en el journal del sistema.

---

## 4. Gestión de Servicios

| Comando | Acción |
|---|---|
| `sudo systemctl status ema.service` | Ver estado de la aplicación |
| `sudo systemctl restart ema.service` | Reiniciar el stack Docker completo |
| `sudo systemctl status ema-watchdog.service` | Ver estado del monitor de salud |
| `journalctl -u ema.service -f` | Ver logs en tiempo real del arranque |
| `journalctl -u ema-watchdog.service -f` | Ver eventos del perro guardián |
| `sudo /opt/ema/rpi/scripts/backup.sh` | Generar copia de seguridad de la base de datos |
