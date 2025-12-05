"""
ILI9341 Display-Treiber für ESP32 CYD
Bietet grundlegende Display-Funktionen für die Sampler-UI
"""

import gc
from machine import Pin, SPI, PWM
from config import DISPLAY_CONFIG

class ILI9341Display:
    """ILI9341 Display-Steuerung"""
    
    def __init__(self):
        self.width = DISPLAY_CONFIG['width']
        self.height = DISPLAY_CONFIG['height']
        
        # GPIO Setup
        self.dc = Pin(DISPLAY_CONFIG['dc'], Pin. OUT)
        self.rst = Pin(DISPLAY_CONFIG['rst'], Pin.OUT)
        self.cs = Pin(DISPLAY_CONFIG['cs'], Pin.OUT)
        
        # Backlight PWM
        self.bl = PWM(Pin(DISPLAY_CONFIG['bl']))
        self.bl.freq(1000)
        self.bl.duty(1023)  # 100% Helligkeit
        
        # SPI initialisieren
        self.spi = SPI(
            DISPLAY_CONFIG['spi_bus'],
            baudrate=DISPLAY_CONFIG['freq'],
            polarity=0,
            phase=0,
            bits=8,
            firstbit=SPI.MSB,
            mosi=Pin(DISPLAY_CONFIG['mosi']),
            miso=Pin(DISPLAY_CONFIG['miso']),
            sck=Pin(DISPLAY_CONFIG['clk'])
        )
        
        self.reset()
        self.init_display()
        
    def reset(self):
        """Display zurücksetzen"""
        self. rst.off()
        import time
        time.sleep_ms(50)
        self. rst.on()
        time. sleep_ms(150)
        
    def write_cmd(self, cmd):
        """Kommando schreiben"""
        self.dc.off()
        self.cs.off()
        self.spi. write(bytes([cmd]))
        self.cs.on()
        
    def write_data(self, data):
        """Daten schreiben"""
        if isinstance(data, int):
            data = bytes([data])
        self.dc.on()
        self.cs.off()
        self.spi. write(data)
        self. cs.on()
        
    def init_display(self):
        """Display initialisieren (vereinfachte Version)"""
        # Software Reset
        self.write_cmd(0x01)
        import time
        time.sleep_ms(100)
        
        # Display ON
        self.write_cmd(0x29)
        
        # Memory Access Control (Rotation)
        self.write_cmd(0x36)
        self.write_data(0x48)  # BGR, Y-Mirror
        
        # COLMOD - Pixel Format
        self.write_cmd(0x3A)
        self.write_data(0x55)  # 16-bit RGB565
        
    def set_window(self, x0, y0, x1, y1):
        """Zeichenfenster setzen"""
        # Column Address Set
        self.write_cmd(0x2A)
        self.write_data(bytes([x0 >> 8, x0 & 0xFF, x1 >> 8, x1 & 0xFF]))
        
        # Row Address Set
        self.write_cmd(0x2B)
        self.write_data(bytes([y0 >> 8, y0 & 0xFF, y1 >> 8, y1 & 0xFF]))
        
    def write_pixel(self, x, y, color_565):
        """Einzelnes Pixel schreiben (RGB565)"""
        self.set_window(x, y, x, y)
        self.write_cmd(0x2C)
        self.write_data(color_565)
        
    def fill_rect(self, x, y, width, height, color_565):
        """Rechteck füllen"""
        self.set_window(x, y, x + width - 1, y + height - 1)
        self.write_cmd(0x2C)
        
        # Farbe als 2 Bytes
        color_bytes = bytes([color_565 >> 8, color_565 & 0xFF])
        pixel_count = width * height
        
        # Speicher optimieren
        self.dc.on()
        self.cs.off()
        for _ in range(pixel_count):
            self.spi.write(color_bytes)
        self.cs.on()
        
    def clear(self, color_565=0xFFFF):
        """Display leeren"""
        self.fill_rect(0, 0, self.width, self.height, color_565)
        gc.collect()
        
    def set_brightness(self, brightness):
        """Helligkeit setzen (0-100)"""
        duty = int((brightness / 100) * 1023)
        self.bl. duty(duty)
        
    def draw_text(self, x, y, text, color_565, bg_color_565=None):
        """Text zeichnen (vereinfacht - benötigt Font-Library)"""
        # Placeholder: würde mit micropython-font-library implementiert
        pass