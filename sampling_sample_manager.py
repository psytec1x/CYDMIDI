"""
Zentrale Sample-Verwaltung und Slot-Zuordnung
"""

from config import CIRCUIT_TRACKS_CONFIG
import gc

class SampleManager:
    """Sample-Verwaltung"""
    
    def __init__(self, sd_manager, midi_controller):
        self.sd_manager = sd_manager
        self. midi_controller = midi_controller
        self.slots = {}  # slot_number -> sample_info
        self.pending_uploads = []
        
        # Slots initialisieren
        for i in range(CIRCUIT_TRACKS_CONFIG['num_slots']):
            self. slots[i] = {
                'name': None,
                'data': None,
                'size': 0,
                'status': 'empty'  # empty, loaded, uploaded
            }
            
    def assign_sample_to_slot(self, slot_number, sample_path):
        """Sample einem Slot zuweisen"""
        if slot_number not in self. slots:
            return False
            
        # Sample von SD-Karte lesen
        sample_data = self.sd_manager.read_sample(sample_path)
        if not sample_data:
            return False
            
        # Im Slot speichern
        filename = sample_path.split('/')[-1]
        self.slots[slot_number] = {
            'name': filename,
            'data': sample_data,
            'size': len(sample_data),
            'status': 'loaded'
        }
        
        # Zum Upload-Queue hinzufügen
        self.pending_uploads.append(slot_number)
        
        gc.collect()
        return True
        
    def upload_slot(self, slot_number):
        """Slot zum Circuit Tracks hochladen"""
        slot_data = self.slots. get(slot_number)
        if not slot_data or not slot_data['data']:
            return False
            
        success = self.midi_controller.upload_sample_to_slot(
            slot_data['data'],
            slot_number
        )
        
        if success:
            slot_data['status'] = 'uploaded'
            return True
            
        return False
        
    def upload_all_pending(self):
        """Alle ausstehenden Slots hochladen"""
        for slot_num in self.pending_uploads:
            self.upload_slot(slot_num)
        self.pending_uploads.clear()
        
    def get_slot_info(self, slot_number):
        """Slot-Informationen abrufen"""
        return self.slots.get(slot_number)
        
    def clear_slot(self, slot_number):
        """Slot leeren"""
        self.slots[slot_number] = {
            'name': None,
            'data': None,
            'size': 0,
            'status': 'empty'
        }