"""
Touch-optimierter Datei-Browser für Sample-Verwaltung
"""

from ui.widgets import FileBrowser, Widget
from utils.colors import Colors

class SampleBrowser(FileBrowser):
    """Spezialisierter Browser für Sample-Dateien"""
    
    def __init__(self, x, y, width, height, sd_manager):
        super().__init__(x, y, width, height)
        self.sd_manager = sd_manager
        self.current_directory = None
        self.dragging_file = None
        self.drag_start_x = None
        self.drag_start_y = None
        
    def load_samples(self):
        """Sample-Dateien laden"""
        samples = self.sd_manager.list_samples()
        self.set_files(samples)
        
    def on_touch_down(self, x, y):
        """Touch-Down im Browser - Drag Start"""
        super().on_touch_down(x, y)
        file = self.get_selected_file()
        if file:
            self.dragging_file = file
            self.drag_start_x = x
            self.drag_start_y = y
            
    def on_touch_up(self, x, y):
        """Touch-Up im Browser - Drag End"""
        super().on_touch_up(x, y)
        self.dragging_file = None
        
    def draw(self, display):
        """Browser zeichnen"""
        display.fill_rect(self.x, self.y, self.width, self.height, Colors. DARKGRAY)
        
        item_height = 20
        for i in range(self.items_visible):
            file_index = self.scroll_offset + i
            if file_index >= len(self. files):
                break
                
            file = self. files[file_index]
            item_y = self.y + (i * item_height)
            
            # Highlight für selected
            if i == (self.selected_index - self.scroll_offset):
                display.fill_rect(self.x, item_y, self.width, item_height, Colors.BLUE)
            
            # TODO: Text-Rendering für Dateinamen