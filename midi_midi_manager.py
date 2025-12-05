"""
MIDI-Kommunikation und Geräte-Verwaltung
"""

from machine import UART, Pin
from config import MIDI_CONFIG
import time

class MIDIManager:
    """Zentrale MIDI-Verwaltung"""
    
    def __init__(self):
        self.uart = None
        self.devices = {}
        self.init_midi_uart()
        
    def init_midi_uart(self):
        """MIDI UART initialisieren"""
        try:
            self.uart = UART(
                MIDI_CONFIG['uart_id'],
                baudrate=MIDI_CONFIG['baud'],
                tx=MIDI_CONFIG['tx_pin'],
                rx=MIDI_CONFIG['rx_pin']
            )
            print("✓ MIDI UART initialisiert")
        except Exception as e:
            print(f"✗ MIDI UART Fehler: {e}")
            
    def send_midi_message(self, status, data1, data2=None):
        """Standard MIDI-Nachricht senden"""
        if not self.uart:
            return False
            
        message = bytes([status, data1])
        if data2 is not None:
            message += bytes([data2])
            
        try:
            self.uart.write(message)
            return True
        except Exception as e:
            print(f"MIDI Send Error: {e}")
            return False
            
    def send_sysex(self, manufacturer_id, data):
        """SysEx-Nachricht senden"""
        if not self. uart:
            return False
            
        # SysEx Start (0xF0)
        message = bytes([0xF0])
        
        # Hersteller-ID (1-3 Bytes)
        if isinstance(manufacturer_id, (tuple, list)):
            message += bytes(manufacturer_id)
        else:
            message += bytes([manufacturer_id])
            
        # Daten
        message += bytes(data)
        
        # SysEx End (0xF7)
        message += bytes([0xF7])
        
        try:
            self.uart.write(message)
            return True
        except Exception as e:
            print(f"SysEx Send Error: {e}")
            return False
            
    def read_midi_message(self):
        """MIDI-Nachricht lesen"""
        if not self.uart or self.uart.any() == 0:
            return None
            
        try:
            status = self.uart.read(1)[0]
            
            # Status-Byte analysieren
            if status == 0xF0:  # SysEx
                sysex_data = []
                while True:
                    byte = self. uart.read(1)[0]
                    if byte == 0xF7:
                        break
                    sysex_data.append(byte)
                return ('sysex', sysex_data)
                
            elif status & 0xF0 == 0x90:  # Note On
                note = self.uart.read(1)[0]
                velocity = self. uart.read(1)[0]
                channel = status & 0x0F
                return ('note_on', channel, note, velocity)
                
            elif status & 0xF0 == 0x80:  # Note Off
                note = self.uart.read(1)[0]
                velocity = self. uart.read(1)[0]
                channel = status & 0x0F
                return ('note_off', channel, note, velocity)
                
            elif status & 0xF0 == 0xB0:  # CC
                cc = self.uart.read(1)[0]
                value = self. uart.read(1)[0]
                channel = status & 0x0F
                return ('cc', channel, cc, value)
                
        except:
            pass
            
        return None
        
    def detect_devices(self):
        """Angeschlossene Geräte erkennen"""
        # Vereinfachte Erkennung: Identity Request senden
        identity_request = [0x7E, 0x00, 0x06, 0x01]  # Universal SysEx
        self.send_sysex([0x7E], identity_request)
        
        # Auf Responses warten
        time.sleep_ms(500)
        responses = []
        
        while self.uart and self.uart.any():
            msg = self.read_midi_message()
            if msg and msg[0] == 'sysex':
                responses.append(msg[1])
                
        return responses