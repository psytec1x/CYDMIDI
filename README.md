# ESP32 CYD MIDI Sampler & Controller

Ein vollständiges MicroPython-Projekt für das **ESP32 CYD (Cheap Yellow Display, ESP32-2432S028R)**, das als Touch-basiertes Werkzeug zur Verwaltung von Sample-Slots auf dem **Novation Circuit Tracks** fungiert.

## 🎯 Features

- **Touch-UI**: 8x8 Sample-Slot-Grid mit Drag-and-Drop
- **Datei-Browser**: Navigation durch Sample-Dateien auf SD-Karte
- **MIDI/SysEx**: Kommunikation mit Circuit Tracks über UART-MIDI
- **Sample-Management**: Upload zu Circuit Tracks Slots
- **Real-time Feedback**: Visueller Status für Upload-Prozesse

---

## 🔧 Hardware-Setup

### Benötigte Komponenten

- **ESP32 CYD** (ESP32-2432S028R) - ca. 15€
  - 2. 8" ILI9341 Display (320x240)
  - XPT2046 Touchscreen (resistiv)
- **SD-Karte Module** (SPI)
- **USB-zu-Serial Adapter** (für UART MIDI)
  - Optional: USB Host Adapter für USB-MIDI
- **Micro-USB Kabel** (für Programmierung)

### Pin-Belegung (Wichtig!)

| Funktion | Pin | Besonderheit |
|----------|-----|---|
| Display MOSI | GPIO 13 | HSPI |
| Display MISO | GPIO 12 | HSPI |
| Display CLK | GPIO 14 | HSPI |
| Display CS | GPIO 15 | - |
| Display DC | GPIO 2 | - |
| Display RST | GPIO 4 | - |
| Display BL | GPIO 21 | PWM |
| Touch MOSI | GPIO 32 | VSPI |
| Touch MISO | GPIO 35 | VSPI |
| Touch CLK | GPIO 25 | VSPI |
| Touch CS | GPIO 33 | - |
| Touch IRQ | GPIO 36 | Input-Only |
| SD MOSI | GPIO 23 | - |
| SD MISO | GPIO 19 | - |
| SD CLK | GPIO 18 | - |
| SD CS | GPIO 5 | - |
| MIDI TX | GPIO 17 | UART2 |
| MIDI RX | GPIO 16 | UART2 |

---

## 📦 Installation

### 1. MicroPython flashen

```bash
# esptool.py installieren
pip install esptool

# ESP32 CYD an USB anschließen
# Port finden (z.B. /dev/ttyUSB0 oder COM3)

# Flashen (neueste Version empfohlen)
esptool.py --chip esp32 --port /dev/ttyUSB0 erase_flash

# MicroPython Binary herunterladen von:
# https://micropython.org/download/esp32/

esptool.py --chip esp32 --port /dev/ttyUSB0 \
  --baud 460800 write_flash -z 0x1000 esp32-20240105-v1.22.0.bin
```

### 2. Dateien auf ESP32 kopieren

```bash
# Mit mpremote (empfohlen)
pip install mpremote

mpremote connect /dev/ttyUSB0

# Projekt-Dateien hochladen
mpremote mkdir :/drivers
mpremote mkdir :/midi
mpremote mkdir :/ui
mpremote mkdir :/sampling
mpremote mkdir :/utils

mpremote cp main.py :/
mpremote cp boot.py :/
mpremote cp config.py :/
mpremote cp drivers/display.py :/drivers/
mpremote cp drivers/touchscreen.py :/drivers/
mpremote cp drivers/sdcard.py :/drivers/
# ...  weitere Dateien
```

Oder mit **ampy**:
```bash
pip install adafruit-ampy

ampy --port /dev/ttyUSB0 put main.py
ampy --port /dev/ttyUSB0 put boot.py
# etc.
```

### 3. Abhängigkeiten (frozen modules)

Für optimale Performance, kompilieren Sie häufig verwendete Module:

```bash
# MicroPython Source klonen
git clone https://github. com/micropython/micropython.git
cd micropython/ports/esp32

# config.h anpassen für mehr RAM:
# #define MICROPY_ALLOC_HEAP_BYTES (150 * 1024)

# Mit Frozen Modules compilieren
make USER_C_MODULES=../../micropython-usermodules \
  FROZEN_MANIFEST=../../../frozen_manifest.txt
```

---

## 🚀 Erste Schritte

### Starten

```bash
# Serielle Verbindung öffnen
screen /dev/ttyUSB0 115200
# oder
picocom /dev/ttyUSB0 -b 115200

# ESP32 aufwecken (Enter drücken oder Reset)
# Sollte Startup-Meldung anzeigen
```

### Kalibrierung

Beim ersten Start sollte der Touchscreen kalibriert werden:

```python
# REPL eingeben
from drivers.touchscreen import XPT2046Touchscreen
ts = XPT2046Touchscreen()
ts.calibrate()
# Befolgen Sie die Anweisungen auf dem Display
```

---

## 💡 Wichtige MicroPython-Konzepte

### 1. **Speicherverwaltung**

Die ESP32 hat begrenzt RAM (~250KB für Anwendungen).  Wichtige Tipps:

```python
import gc

# Regelmäßig freigeben
gc.collect()

# RAM-Status
gc.mem_free()  # Verfügbarer RAM
gc.mem_alloc() # Allokierter RAM

# Strings sparen
s = "test"       # Zu vermeiden bei Schleifen
b = b"test"      # Bytes sparen Speicher
```

### 2. **UART & MIDI**

```python
from machine import UART

# MIDI-UART (31. 25 kBaud standard)
midi = UART(2, baudrate=31250, tx=17, rx=16)

# Nachricht senden
midi.write(bytes([0x90, 0x3C, 0x7F]))  # Note On

# Nachricht empfangen
if midi.any():
    data = midi.read(3)
    print(data)
```

### 3. **SPI für Display & Touch**

```python
from machine import SPI, Pin

# Two separate SPI buses! 
# Display: SPI 2 (HSPI)
spi_display = SPI(2, baudrate=40_000_000, ...)

# Touch: SPI 1 (VSPI)
spi_touch = SPI(1, baudrate=2_000_000, ...)
```

### 4. **Pin-Konfiguration**

```python
# Wichtig: Manche Pins haben Beschränkungen
# GPIO 34-39: Input-only (keine Ausgabe möglich)
# GPIO 34, 36: Nur für ADC (Touchscreen IRQ)

# JTAG Pins (GPIO 12-15): Vorsicht beim Debugging
# STRAPPING Pins (GPIO 0, 2, 5, 12, 15): Beeinflussen Boot
```

---

## 🎨 Display-Ausgabe (Advanced)

### Option 1: LVGL (Light and Versatile Graphics Library)

```python
# Installieren: https://github.com/lvgl/lv_micropython
# Bietet grafische Widgets, aber speicherintensiv

import lvgl as lv
lv. init()

# Screen erstellen
scr = lv.obj(None)
btn = lv.btn(scr)
btn.set_size(100, 50)

lv.disp_load_actions(scr)
```

### Option 2: uGUI (einfacher)

```python
# https://github.com/boochow/micropython-ugui
# Leichtgewichtig, ideal für begrenzte Ressourcen

from ugui import Label, Button

label = Label(x=10, y=10, width=100, height=20, text="Hello")
```

### Option 3: Manuelles Rendering (wie hier)

```python
# Direkte Display-Befehle
# Schnell, aber speichereffizient
display.fill_rect(10, 10, 50, 50, 0xFFFF)
```

---

## 🔌 MIDI-Kommunikation

### Serielle MIDI über USB

```
ESP32 (UART) -> USB-Serial Adapter -> Computer/Circuit Tracks
```

**Bekannte FTDI-Adapter:**
- SparkFun Pro Micro
- Arduino Leonardo (mit MIDI-Firmware)
- Teensy (besondere MIDI-Unterstützung)

### Bluetooth MIDI (BLE)

```python
# Benötigt: nimble oder Bluetooth Stack
# Noch nicht vollständig implementiert
# Würde BLE Peripheral mit MIDI Service erstellen
```

---

## 🔧 Troubleshooting

### Problem: Display bleibt schwarz

```python
# 1. Backlight testen
from machine import PWM, Pin
bl = PWM(Pin(21))
bl.duty(512)  # 50%

# 2. SPI-Kommunikation testen
from drivers.display import ILI9341Display
display = ILI9341Display()
display.fill_rect(0, 0, 320, 240, 0xFF00)  # Grün
```

### Problem: Touch reagiert nicht

```python
# 1. IRQ-Pin prüfen
from machine import Pin
irq = Pin(36, Pin.IN)
print(irq.value())  # Sollte 0 sein wenn Touch gedrückt

# 2.  Kalibrierung durchführen
from drivers.touchscreen import XPT2046Touchscreen
ts = XPT2046Touchscreen()
ts. calibrate()
```

### Problem: Speicher voll

```python
# Frozen Modules compilieren
# Nur kritische Dateien hochladen
# Größere Libraries vermeiden

import gc
gc.collect()
import micropython
micropython.mem_info()
```

### Problem: MIDI-Daten werden nicht empfangen

```python
# 1.  Baud-Rate testen
from machine import UART
uart = UART(2, baudrate=31250)

# 2. Verbindung prüfen
print(f"Bytes available: {uart.any()}")

# 3. Mit Loop-Back testen
# TX und RX kurzschließen
uart.write(b"TEST")
data = uart.read()
print(data)
```

---

## 📊 Performance-Tipps

| Optimierung | Effekt |
|---|---|
| Frozen Modules | +30% Speed |
| `gc.collect()` regelmäßig | Verhindert Crashes |
| OTA-Updates | Einfacheres Update-Management |
| Display nur bei Bedarf zeichnen | +50% Boot-Speed |
| SPI Baudrate optimieren | Schnellere Kommunikation |

---

## 🎓 Weitere Ressourcen

- **MicroPython Docs**: https://docs.micropython. org
- **ESP32 Pinout**: https://random-nerd-tutorials.com/esp32-pinout-reference-gpios/
- **Circuit Tracks MIDI Spec**: https://novationmusic.com (Produktseite)
- **MIDI SysEx Tutorial**: https://www.midi.org/specifications-old