"""
Novation Circuit Tracks - Spezifische SysEx-Befehle
"""

from config import CIRCUIT_TRACKS_CONFIG
from midi_manager import MIDIManager
import time

class CircuitTracksController(MIDIManager):
    """Circuit Tracks MIDI-Steuerung"""
    
    # SysEx Device Inquiry Response Pattern
    DEVICE_INQUIRY = [0x7E, 0x00, 0x06, 0x02]  # Identity Reply
    
    def __init__(self):
        super().__init__()
        self.device_connected = False
        self.num_slots = CIRCUIT_TRACKS_CONFIG['num_slots']
        self.slots = {}
        
    def detect_circuit_tracks(self):
        """Circuit Tracks erkennen"""
        responses = self.detect_devices()
        
        for resp in responses:
            # Hersteller-ID 0x002029 = Novation
            if len(resp) >= 3:
                if resp[0:3] == [0x00, 0x20, 0x29]:
                    self.device_connected = True
                    print("✓ Novation Circuit Tracks erkannt!")
                    return True
                    
        print("✗ Circuit Tracks nicht gefunden")
        return False
        
    def upload_sample_to_slot(self, sample_data, slot_number):
        """Sample in einen Slot laden"""
        if not self.device_connected:
            print("Circuit Tracks nicht verbunden")
            return False
            
        if not isinstance(sample_data, bytes):
            return False
            
        # SysEx: Sample Upload
        # [F0] [00 20 29] [Device] [Cmd] [Slot] [Data... ] [F7]
        
        manufacturer_id = CIRCUIT_TRACKS_CONFIG['manufacturer_id']
        device_id = CIRCUIT_TRACKS_CONFIG['device_id']
        
        # Vereinfachte SysEx (16-Bit Länge + Daten)
        sysex_data = [
            device_id,
            0x01,  # Upload Sample Command
            slot_number & 0xFF,  # Slot Low Byte
        ]
        
        # Sample-Daten in SysEx-Format (7-Bit encoding nötig!)
        encoded_data = self.encode_7bit(sample_data)
        sysex_data.extend(encoded_data[:256])  # Limit für Übertragung
        
        return self.send_sysex(manufacturer_id, sysex_data)
        
    def encode_7bit(self, data):
        """8-Bit Daten zu 7-Bit SysEx-Format kodieren"""
        encoded = []
        bit_buffer = 0
        bits_in_buffer = 0
        
        for byte in data:
            for bit in range(8):
                bit_buffer = (bit_buffer << 1) | ((byte >> bit) & 1)
                bits_in_buffer += 1
                
                if bits_in_buffer == 7:
                    encoded.append(bit_buffer)
                    bit_buffer = 0
                    bits_in_buffer = 0
                    
        return encoded
        
    def decode_7bit(self, encoded_data):
        """7-Bit SysEx-Daten zu 8-Bit dekodieren"""
        decoded = []
        bit_buffer = 0
        bits_in_buffer = 0
        
        for byte in encoded_data:
            for bit in range(7):
                bit_buffer = (bit_buffer << 1) | ((byte >> bit) & 1)
                bits_in_buffer += 1
                
                if bits_in_buffer == 8:
                    decoded.append(bit_buffer)
                    bit_buffer = 0
                    bits_in_buffer = 0
                    
        return bytes(decoded)
        
    def get_sample_slot(self, slot_number):
        """Sample-Slot auslesen"""
        if not self. device_connected:
            return None
            
        # Query Sample Slot Command
        sysex_data = [
            CIRCUIT_TRACKS_CONFIG['device_id'],
            0x02,  # Query Slot Command
            slot_number & 0xFF,
        ]
        
        self.send_sysex(CIRCUIT_TRACKS_CONFIG['manufacturer_id'], sysex_data)
        
        # Auf Response warten
        time.sleep_ms(200)
        return None  # Placeholder
        
    def save_project(self):
        """Projekt auf Circuit Tracks speichern"""
        if not self.device_connected:
            return False
            
        sysex_data = [
            CIRCUIT_TRACKS_CONFIG['device_id'],
            0x03,  # Save Project Command
        ]
        
        return self.send_sysex(CIRCUIT_TRACKS_CONFIG['manufacturer_id'], sysex_data)