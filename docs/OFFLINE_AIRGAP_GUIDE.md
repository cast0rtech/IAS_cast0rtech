# Guía de Instalación 100% Offline (Air-Gapped) - EMA Alpine OS

Esta guía explica cómo utilizar el **paquete totalmente autónomo y fuera de línea** (*air-gapped*) de **EMA Industrial Alpine OS** para desplegar la Raspberry Pi en instalaciones industriales críticas sin conexión a Internet (subestaciones, plantas aisladas o redes cerradas OT).

---

## 1. ¿Qué incluye el Paquete Offline?

El archivo generado `dist/alpine-ema-os/ema-alpine-offline-airgap.zip` (peso aprox. **75 MB**) contiene **TODO** lo necesario:

1. **Kernel y Firmware Oficial Raspberry Pi**:
   - Soporte para Raspberry Pi 3B+, 4, 5, CM4 y CM5 (`vmlinuz-rpi`, `initramfs-rpi`, `modloop-rpi`, árboles de dispositivos `.dtb` y `overlays/`).
2. **Sistema Operativo Base en RAM (Alpine aarch64)**:
   - Gestor de servicios ultra-rápido *OpenRC*, *Busybox*, utilidades de red y herramientas de disco.
3. **Servidores y Demonios Nativos**:
   - Servidor web **Nginx** optimizado con proxy inverso para WebSockets y API.
   - Sincronizador de reloj industrial **Chrony** (NTP local o mediante RTC).
   - Perro guardián por hardware (**BCM2835 Watchdog**) armado para reiniciar en 15 s ante congelaciones.
   - Demonio de supervisión continua de la aplicación (**ema-watchdog**).
4. **Entorno Python y Dependencias Binarias (Wheelhouse ARM64)**:
   - Incluye los 21 paquetes binarios precompilados en `rpi/alpine/wheels/`:
     `fastapi`, `uvicorn`, `sqlmodel`, `pymodbus`, `pydantic`, `pydantic-core`, `SQLAlchemy`, `starlette`, `anyio`, `websockets`, `pyyaml`, etc.
5. **Código Fuente de EMA**:
   - Backend FastAPI completo con sondeo Modbus TCP y SQLite.
   - Frontend interactivo con selector de planos, WebSockets en vivo e idiomas (EN / DE / ES) con cero llamadas externas a CDNs.

---

## 2. Cómo Flashear la Tarjeta SD (Sin Internet)

### En 3 sencillos pasos desde Windows, Mac o Linux:

1. **Formatear la tarjeta MicroSD**:
   - Conecta la tarjeta SD a tu ordenador.
   - Formatea la tarjeta en formato **FAT32** (o utiliza la herramienta oficial *SD Card Formatter*).
2. **Copiar los archivos**:
   - Descomprime el archivo:
     `dist/alpine-ema-os/ema-alpine-offline-airgap.zip`
   - Copia **todo su contenido directamente a la raíz de la tarjeta MicroSD**.
3. **Encender la Raspberry Pi**:
   - Inserta la tarjeta SD en la Raspberry Pi.
   - Conecta el cable de red Ethernet al switch/equipo industrial y dale alimentación.
   - La Raspberry Pi cargará el sistema operativo directamente en la memoria RAM en **3 segundos**.

El panel de supervisión estará disponible inmediatamente en tu navegador:
- **Dashboard Web**: `http://<ip-de-la-raspberry>:8080`
- **Documentación de la API**: `http://<ip-de-la-raspberry>:8000/docs`

---

## 3. Cómo Recompilar el Paquete Offline en el Futuro

Si realizas cambios en el backend, en el frontend o añades nuevas dependencias y necesitas generar un nuevo archivo `.zip` offline:

### En Windows (PowerShell):
```powershell
powershell -ExecutionPolicy Bypass -File .\rpi\alpine\Build-OfflineBundle.ps1
```

### En Linux / macOS / WSL (Bash):
```bash
chmod +x ./rpi/alpine/build-ema-os.sh
./rpi/alpine/build-ema-os.sh
```

El nuevo paquete listo para copiar a la SD se generará en:
`dist/alpine-ema-os/ema-alpine-offline-airgap.zip`
