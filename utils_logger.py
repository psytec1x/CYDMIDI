"""
Einfaches Logging-System
"""

from config import LOG_LEVEL as CONFIG_LOG_LEVEL

class Logger:
    """Logging Utility"""
    
    LEVELS = {
        'DEBUG': 0,
        'INFO': 1,
        'WARNING': 2,
        'ERROR': 3,
    }
    
    def __init__(self, enabled=True, level='INFO'):
        self.enabled = enabled
        self. level = self.LEVELS.get(level, 1)
        
    def log(self, message, level='INFO'):
        """Nachricht loggen"""
        if not self.enabled:
            return
            
        level_num = self.LEVELS. get(level, 1)
        if level_num >= self.level:
            print(f"[{level}] {message}")
            
    def debug(self, msg):
        self.log(msg, 'DEBUG')
        
    def info(self, msg):
        self. log(msg, 'INFO')
        
    def warning(self, msg):
        self.log(msg, 'WARNING')
        
    def error(self, msg):
        self.log(msg, 'ERROR')