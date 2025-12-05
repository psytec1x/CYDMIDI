"""
ESP32 CYD MIDI Sampler - Hauptanwendung
Novation Components-ähnliches Tool für Circuit Tracks
"""

import gc
import time
from machine import Pin

# Konfiguration
from config import DEBUG, LOG_LEVEL, PATHS, UI_CONFIG
from drivers.display import ILI9341Display
from drivers.touchscreen import XPT2046Touchscreen
from drivers.sdcard import SDCardManager
from midi.circuit_tracks import CircuitTracksController
from sampling.sample_manager import SampleManager
from ui.gui import GUIEngine
from ui.widgets import SampleSlot, Button
from ui.file_browser import SampleBrowser
from utils.logger import Logger
from utils.colors import Colors

# Logger initialisieren
logger = Logger(DEBUG, LOG_LEVEL)

class CircuitTracksSampler:
    """Hauptanwendung"""
    
    def __init__(self):
        logger.info("Initialisierung: ESP32 CYD MIDI Sampler")
        
        # Hardware initialisieren
        self.display = ILI9341Display()
        self.touchscreen = XPT2046Touchscreen()
        self.sd_manager = SDCardManager()
        self.midi_controller = CircuitTracksController()
        
        # Managers
        self.sample_manager = None
        self.gui_engine = None
        
        # Status
        self.running = True
        self.upload_in_progress = False
        
    def init(self):
        """Anwendung initialisieren"""
        logger. info("Hardware Setup...")
        
        # SD-Karte
        if not self.sd_manager.init_sdcard():
            logger.error("SD-Karte konnte nicht initialisiert werden!")
            self.show_error_screen("SD-Karte Fehler")
            return False
            
        self.sd_manager.create_directories()
        logger.info("✓ SD-Karte ready")
        
        # MIDI & Circuit Tracks
        logger.info("MIDI Setup...")
        if not self.midi_controller.detect_circuit_tracks():
            logger.warning("Circuit Tracks nicht erkannt - Read-Only Modus")
            # Nicht kritisch - weiterfahren im Simulator-Modus
            
        self.sample_manager = SampleManager(self.sd_manager, self.midi_controller)
        
        # GUI
        self.gui_engine = GUIEngine(self.display, self.touchscreen)
        self.setup_ui()
        
        logger.info("✓ Initialisierung abgeschlossen")
        return True
        
    def setup_ui(self):
        """UI aufbauen"""
        logger.info("UI Setup...")
        
        # Datei-Browser (linke Seite)
        file_browser = SampleBrowser(5, 50, 150, 180, self.sd_manager)
        file_browser.load_samples()
        self.gui_engine.add_widget(file_browser)
        
        # Sample-Slots Grid (rechte Seite - 8x8)
        slots_start_x = 160
        slots_start_y = 50
        slot_spacing = 4
        
        for row in range(UI_CONFIG['grid_rows']):
            for col in range(UI_CONFIG['grid_cols']):
                slot_num = row * UI_CONFIG['grid_cols'] + col
                x = slots_start_x + (col * (UI_CONFIG['slot_width'] + slot_spacing))
                y = slots_start_y + (row * (UI_CONFIG['slot_height'] + slot_spacing))
                
                slot = SampleSlot(x, y, slot_num)
                self.gui_engine. add_widget(slot)
        
        # Control Buttons (unten)
        upload_btn = Button(10, 210, 80, 25, "Upload All", self.upload_all)
        self.gui_engine.add_widget(upload_btn)
        
        save_btn = Button(100, 210, 80, 25, "Save", self.save_project)
        self.gui_engine.add_widget(save_btn)
        
        logger.info("✓ UI Ready")
        
    def show_error_screen(self, message):
        """Fehlerbildschirm anzeigen"""
        self.display.clear(Colors.RED)
        # Text würde hier gerendert
        logger.error(f"ERROR: {message}")
        
    def show_status(self, message, duration_ms=2000):
        """Status-Nachricht anzeigen"""
        logger.info(f"STATUS: {message}")
        # Könnte Toast-Benachrichtigung auf Display zeichnen
        
    def upload_all(self):
        """Alle ausstehenden Slots hochladen"""
        if not self.midi_controller.device_connected:
            self.show_status("Circuit Tracks nicht verbunden!", 3000)
            return
            
        self.upload_in_progress = True
        self.sample_manager.upload_all_pending()
        self.upload_in_progress = False
        self.show_status("Upload abgeschlossen!")
        
    def save_project(self):
        """Projekt speichern"""
        if not self.midi_controller.device_connected:
            self.show_status("Circuit Tracks nicht verbunden!", 3000)
            return
            
        if self.midi_controller.save_project():
            self.show_status("Projekt gespeichert!")
        else:
            self.show_status("Speichern fehlgeschlagen!", 3000)
            
    def run(self):
        """Hauptschleife"""
        logger.info("Starte Hauptschleife...")
        frame_count = 0
        last_gc = time.time()
        
        while self.running:
            try:
                # GUI aktualisieren
                self.gui_engine.update()
                
                # GUI zeichnen (nicht zu oft)
                if frame_count % 10 == 0:
                    self.gui_engine.draw()
                    
                # MIDI-Nachrichten verarbeiten
                midi_msg = self.midi_controller.read_midi_message()
                if midi_msg:
                    self.handle_midi_message(midi_msg)
                    
                # Speicher optimieren
                if time.time() - last_gc > 5:
                    gc.collect()
                    last_gc = time.time()
                    
                frame_count += 1
                time.sleep_ms(50)  # ~20 FPS
                
            except KeyboardInterrupt:
                self.running = False
            except Exception as e:
                logger.error(f"Fehler in Hauptschleife: {e}")
                time.sleep_ms(500)
                
    def handle_midi_message(self, msg):
        """MIDI-Nachricht verarbeiten"""
        if msg[0] == 'sysex':
            logger.debug(f"SysEx empfangen: {msg[1][:20]}...")
        elif msg[0] == 'note_on':
            logger.debug(f"Note On: Channel {msg[1]}, Note {msg[2]}, Velocity {msg[3]}")
        elif msg[0] == 'cc':
            logger.debug(f"CC: Channel {msg[1]}, CC {msg[2]}, Value {msg[3]}")
            
    def cleanup(self):
        """Aufräumen"""
        logger.info("Cleanup...")
        self. display.clear(Colors.BLACK)
        logger.info("Anwendung beendet")


# ===== ENTRY POINT =====
if __name__ == '__main__':
    app = CircuitTracksSampler()
    if app.init():
        app. run()
    app.cleanup()