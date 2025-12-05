"""
XPT2046 Touchscreen-Treiber für ESP32 CYD
Verwaltet Touch-Events und Kalibrierung
"""

from machine import Pin, SPI, ADC
from config import TOUCH_CONFIG
import time

class XPT2046Touchscreen:
    """XPT2046 Resistiver Touchscreen"""
    
    # SPI Command Bytes
    CMD_X_READ = 0xD0
    CMD_Y_READ = 0x90
    CMD_Z1_READ = 0xB0
    CMD_Z2_READ = 0xC0
    
    def __init__(self):
        self.width = TOUCH_CONFIG['width']
        self.height = TOUCH_CONFIG['height']
        self.calibration = TOUCH_CONFIG['calibration']
        
        # GPIO Setup
        self.cs = Pin(TOUCH_CONFIG['cs'], Pin.OUT, value=1)
        self.irq = Pin(TOUCH_CONFIG['irq'], Pin.IN)
        
        # SPI initialisieren
        self.spi = SPI(
            TOUCH_CONFIG['spi_bus'],
            baudrate=TOUCH_CONFIG['freq'],
            polarity=0,
            phase=0,
            bits=8,
            firstbit=SPI.MSB,
            mosi=Pin(TOUCH_CONFIG['mosi']),
            miso=Pin(TOUCH_CONFIG['miso']),
            sck=Pin(TOUCH_CONFIG['clk'])
        )
        
        # Zustand
        self. last_x = None
        self. last_y = None
        self.pressed = False
        
    def read_raw(self, cmd):
        """Rohwert von Touchscreen lesen"""
        self.cs.off()
        time.sleep_us(10)
        
        self.spi.write(bytes([cmd]))
        response = self.spi.read(2)
        
        time.sleep_us(10)
        self.cs.on()
        
        # 12-Bit Wert extrahieren
        value = ((response[0] << 8) | response[1]) >> 3
        return value & 0x0FFF
        
    def read_calibrated(self):
        """Kalibrierte Touch-Koordinaten lesen"""
        # Mehrfach lesen für Stabilität
        x_values = []
        y_values = []
        
        for _ in range(3):
            x = self.read_raw(self.CMD_X_READ)
            y = self.read_raw(self.CMD_Y_READ)
            x_values.append(x)
            y_values.append(y)
            time.sleep_ms(10)
        
        # Median nehmen
        x_raw = sorted(x_values)[1]
        y_raw = sorted(y_values)[1]
        
        # Kalibrierung anwenden
        cal = self.calibration
        x_mapped = int((x_raw - cal['x_min']) / (cal['x_max'] - cal['x_min']) * self. width)
        y_mapped = int((y_raw - cal['y_min']) / (cal['y_max'] - cal['y_min']) * self.height)
        
        # Grenzen beachten
        x_mapped = max(0, min(self.width - 1, x_mapped))
        y_mapped = max(0, min(self. height - 1, y_mapped))
        
        return x_mapped, y_mapped
        
    def is_pressed(self):
        """Prüfe, ob Touch aktiv ist"""
        return self. irq.value() == 0
        
    def get_touch(self):
        """Touch-Event abrufen"""
        if self. is_pressed():
            x, y = self.read_calibrated()
            self.last_x = x
            self.last_y = y
            self. pressed = True
            return ('touch_down', x, y)
        else:
            if self.pressed:
                self.pressed = False
                return ('touch_up', self.last_x, self. last_y)
        return None
        
    def calibrate(self):
        """Interaktive Kalibrierung (placeholder)"""
        print("Touch Kalibrierung gestartet...")
        # Würde Display-Prompts anzeigen
        pass