# EMA Industrial Alpine OS (Sistema Operativo Embebido en RAM)

**EMA Industrial Alpine OS** es un sistema operativo embebido autónomo (*standalone*) creado específicamente para la Raspberry Pi (3B+, 4, 5, CM4, CM5), **sin utilizar Raspberry Pi OS Lite ni Debian**.

---

## 1. ¿Por qué un sistema operativo en RAM (Diskless)?

En instalaciones industriales (cuadros eléctricos, subestaciones, centros de bombeo o plantas solares), las pérdidas imprevistas de tensión son frecuentes. Los sistemas operativos tradicionales (como Raspberry Pi OS Lite o Ubuntu) escriben constantemente logs y estados en la tarjeta SD; al cortarse la luz, la tabla de particiones o el sistema de archivos suelen corromperse.

### Ventajas de EMA Alpine OS:
- **100% Inmune a cortes de luz**: El sistema operativo raíz (`/`) se carga íntegramente en la memoria RAM (`tmpfs`) durante el arranque. La partición de la SD permanece de solo lectura o desmontada.
- **Arranque en 3 segundos**: Al no depender de pesadas dependencias de *systemd*, el gestor *OpenRC* arranca los servicios en milisegundos.
- **Consumo mínimo de recursos**: Menos de 60 MB de memoria RAM total (frente a 400–800 MB de distribuciones convencionales).
- **Huella de almacenamiento mínima**: La imagen completa pesa menos de 150 MB.
- **Hardware Watchdog activo**: Integrado con el temporizador por hardware `bcm2835_wdt` del procesador Broadcom.

---

## 2. Arquitectura de EMA Alpine OS

```
+-------------------------------------------------------------------------+
|                  Tarjeta MicroSD / Almacenamiento Flash                 |
|                                                                         |
|  [ Partición 1: FAT32 (1 GB) - Solo Lectura ]                           |
|  * Firmware Raspberry Pi (bootcode.bin, start4.elf, dtb...)             |
|  * Linux Kernel aarch64 + Initramfs                                     |
|  * Overlay de configuración: ema-gateway.apkovl.tar.gz                  |
|                                                                         |
|  [ Partición 2: ext4 (Resto de la tarjeta) - Persistencia ]             |
|  * Montado en /data (Base de datos SQLite: ema.db en modo WAL)          |
|  * Copias de seguridad automáticas y logs de auditoría                  |
+-------------------------------------------------------------------------+
                                    |
                                    | Carga en arranque (3 seg)
                                    v
+-------------------------------------------------------------------------+
|                          Memoria RAM (tmpfs)                            |
|                                                                         |
|  * / (Sistema de archivos inmutable en memoria)                         |
|  * Nginx (Puerto 8080 - Dashboard y WebSockets)                         |
|  * EMA Backend FastAPI (Puerto 8000 - Modbus Poller, SQLite)            |
|  * Chrony (Sincronización horaria de precisión para alarmas)            |
|  * Watchdog Daemon (Supervisión continua y reinicio automático)         |
+-------------------------------------------------------------------------+
```

---

## 3. Cómo Construir el Sistema Operativo

En tu máquina Linux, macOS o entorno WSL:

```bash
# Otorgar permisos de ejecución al generador
chmod +x rpi/alpine/build-ema-os.sh

# Construir el sistema operativo
./rpi/alpine/build-ema-os.sh
```

El script descargará los binarios del kernel oficial aarch64, generará el overlay `ema-gateway.apkovl.tar.gz` con el código de EMA y creará el paquete final en:
`dist/alpine-ema-os/ema-alpine-os-aarch64.zip`

---

## 4. Cómo Flashear la Tarjeta SD

### Método Rápido (Cualquier Sistema Operativo: Windows, Mac, Linux):
1. Inserta la tarjeta SD en tu ordenador.
2. Formatea la tarjeta en **FAT32** con cualquier herramienta estándar (ej. *SD Card Formatter* o el formateador de Windows).
3. Descomprime el contenido de `dist/alpine-ema-os/ema-alpine-os-aarch64.zip` **directamente en la raíz de la tarjeta SD**.
4. Expulsa la tarjeta SD, insértala en la Raspberry Pi y conéctala a la alimentación.
5. En 3 segundos estará en marcha.

### Método Avanzado con Doble Partición (Recomendado para Persistencia Industrial):
Utiliza el script automatizado para crear la partición de arranque (FAT32) y la partición de datos persistentes (ext4):

```bash
sudo ./rpi/alpine/flash-sd.sh /dev/sdX
# (Sustituye /dev/sdX por el dispositivo de tu tarjeta SD)
```

---

## 5. Gestión del Sistema en Producción

### Acceso
- **Dashboard Web**: `http://<ip-raspberry>:8080`
- **Documentación API**: `http://<ip-raspberry>:8000/docs`
- **Consola SSH**: `ssh root@<ip-raspberry>` (sin contraseña por defecto en primer arranque, o configurada en overlay).

### Control de Servicios (OpenRC)
```sh
# Estado del backend
rc-service ema-backend status

# Reiniciar backend
rc-service ema-backend restart

# Estado del servidor web Nginx
rc-service nginx status

# Estado del perro guardián
rc-service ema-watchdog status
```

### Guardar Cambios de Configuración (`lbu`)
Como el sistema corre en RAM, si modificas algún archivo de configuración en `/etc` y quieres que persista tras un reinicio, guarda los cambios con la utilidad de Alpine:

```sh
lbu commit -d
```
Esto actualiza automáticamente el archivo `ema-gateway.apkovl.tar.gz` en la tarjeta SD de forma atómica y segura.
