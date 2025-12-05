"""
ESP32 CYD MIDI Sampler - Konfiguration
Zentrale Konfigurationsdatei für Hardware-Pins und Anwendungseinstellungen
"""

# ===== DISPLAY & TOUCHSCREEN PINS =====
# ESP32 CYD (ESP32-2432S028R) Standard-Pinbelegung
DISPLAY_CONFIG = {
    # ILI9341 SPI-Pins
    'spi_bus': 2,           # HSPI
    'mosi': 13,
    'miso': 12,
    'clk': 14,
    'cs': 15,               # Chip Select
    'dc': 2,                # Data/Command
    'rst': 4,               # Reset
    'bl': 21,               # Backlight PWM
    'width': 320,
    'height': 240,
    'freq': 40_000_000,     # 40MHz SPI-Frequenz
}

# Touchscreen (XPT2046) SPI-Pins
TOUCH_CONFIG = {
    'spi_bus': 1,           # VSPI
    'mosi': 32,
    'miso': 35,
    'clk': 25,
    'cs': 33,
    'irq': 36,              # Interrupt
    'width': 320,
    'height': 240,
    'freq': 2_000_000,      # 2MHz für Touch
    'calibration': {
        'x_min': 250,
        'x_max': 3800,
        'y_min': 250,
        'y_max': 3800,
    }
}

# ===== SD-KARTE PINS =====
SD_CONFIG = {
    'mosi': 23,
    'miso': 19,
    'clk': 18,
    'cs': 5,
    'slot': 1,              # SD1 slot
}

# ===== MIDI KONFIGURATION =====
MIDI_CONFIG = {
    'uart_id': 2,
    'tx_pin': 17,
    'rx_pin': 16,
    'baud': 31250,          # Standard MIDI Baud Rate
    'usb_host_enabled': False,  # USB Host für USB-MIDI
    'ble_midi_enabled': True,   # Bluetooth MIDI
}

# ===== CIRCUIT TRACKS KONFIGURATION =====
CIRCUIT_TRACKS_CONFIG = {
    'num_slots': 64,
    'sample_rate': 22050,   # Hz
    'max_sample_size': 262144,  # 256KB per Sample
    'manufacturer_id': (0x00, 0x20, 0x29),  # Novation
    'device_id': 0x01,
}

# ===== UI KONFIGURATION =====
UI_CONFIG = {
    'grid_cols': 8,         # 8x8 Grid für Sample-Slots
    'grid_rows': 8,
    'slot_width': 40,
    'slot_height': 28,
    'margin': 2,
    'font_size': 1,         # 0=klein, 1=mittel, 2=groß
}

# ===== SAMPLING KONFIGURATION =====
SAMPLING_CONFIG = {
    'supported_formats': ['. wav', '.raw'],
    'max_samples': 100,
    'preview_duration': 2,  # Sekunden
}

# ===== PFADE =====
PATHS = {
    'sd_mount': '/sd',
    'samples': '/sd/samples',
    'config': '/sd/config',
    'backups': '/sd/backups',
}

# ===== DEBUG =====
DEBUG = True
LOG_LEVEL = 'INFO'  # DEBUG, INFO, WARNING, ERROR