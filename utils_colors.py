"""
RGB565 Farbdefinitionen für ILI9341
Konvertierung: RGB(R, G, B) -> ((R & 0xF8) << 8) | ((G & 0xFC) << 3) | (B >> 3)
"""

class Colors:
    """RGB565 Farbpalette"""
    
    BLACK = 0x0000
    WHITE = 0xFFFF
    
    RED = 0xF800
    GREEN = 0x07E0
    BLUE = 0x001F
    
    CYAN = 0x07FF
    MAGENTA = 0xF81F
    YELLOW = 0xFFE0
    
    DARKRED = 0x8000
    DARKGREEN = 0x0400
    DARKBLUE = 0x0010
    
    GRAY = 0x8410
    DARKGRAY = 0x4208
    LIGHTGRAY = 0xC618
    
    ORANGE = 0xFD20
    PURPLE = 0x8010