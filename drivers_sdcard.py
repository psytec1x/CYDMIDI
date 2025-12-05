"""
SD-Karten-Treiber und Dateisystem-Verwaltung
"""

import os
import gc
from machine import Pin, SPI
from config import SD_CONFIG, PATHS

class SDCardManager:
    """SD-Karten-Verwaltung"""
    
    def __init__(self):
        self.mounted = False
        self.mount_point = PATHS['sd_mount']
        
    def init_sdcard(self):
        """SD-Karte initialisieren"""
        try:
            import sdcard
            
            spi = SPI(
                SD_CONFIG['slot'],
                baudrate=25_000_000,
                mosi=Pin(SD_CONFIG['mosi']),
                miso=Pin(SD_CONFIG['miso']),
                sck=Pin(SD_CONFIG['clk'])
            )
            
            cs = Pin(SD_CONFIG['cs'], Pin.OUT)
            sd = sdcard.SDCard(spi, cs)
            
            # Dateisystem mounten
            import vfs
            vfs.mount(sd, self.mount_point)
            self.mounted = True
            
            print(f"✓ SD-Karte gemountet: {self.mount_point}")
            return True
        except Exception as e:
            print(f"✗ SD-Karte Fehler: {e}")
            return False
            
    def create_directories(self):
        """Notwendige Verzeichnisse erstellen"""
        for path in [PATHS['samples'], PATHS['config'], PATHS['backups']]:
            try:
                os.makedirs(path, exist_ok=True)
            except:
                pass
                
    def list_samples(self, directory=None):
        """Sample-Dateien auflisten"""
        if not self.mounted:
            return []
            
        if directory is None:
            directory = PATHS['samples']
            
        try:
            files = []
            for f in os.listdir(directory):
                fpath = f"{directory}/{f}"
                if os.path.isfile(fpath):
                    # Nur unterstützte Formate
                    if any(f.lower().endswith(ext) for ext in ['.wav', '.raw']):
                        size = os.stat(fpath)[6]
                        files.append({
                            'name': f,
                            'path': fpath,
                            'size': size
                        })
            return sorted(files, key=lambda x: x['name'])
        except Exception as e:
            print(f"Fehler beim Auflisten: {e}")
            return []
            
    def get_file_size(self, filepath):
        """Dateigröße abrufen"""
        try:
            return os.stat(filepath)[6]
        except:
            return 0
            
    def read_sample(self, filepath):
        """Sample-Datei lesen"""
        try:
            with open(filepath, 'rb') as f:
                data = f. read()
            gc.collect()
            return data
        except Exception as e:
            print(f"Fehler beim Lesen von {filepath}: {e}")
            return None