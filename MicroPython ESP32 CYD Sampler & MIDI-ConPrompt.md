MicroPython ESP32 CYD Sampler & MIDI-Controller Prompt
Erstelle eine vollständige MicroPython-Anwendung für das ESP32 CYD (Cheap Yellow Display, ESP32-2432S028R), die als Novation Components-ähnliches Werkzeug für Circuit Tracks fungiert. Die Anwendung muss die folgenden Hauptfunktionen implementieren:

1. ⚙️ Hardware-Setup & Bibliotheken
Zielplattform: ESP32 CYD (Cheap Yellow Display).

MicroPython-Version: Aktuelle stabile Version.

Display/Touchscreen: Implementiere die notwendigen Treiber (z.B. für ILI9341 und Touchscreen) und eine geeignete GUI-Bibliothek für MicroPython, die Drag-and-Drop-Funktionalität auf dem resistiven Touchscreen unterstützt (z.B. uGUI oder eine schlanke LVGL-Integration, falls speichertechnisch machbar).

SD-Karte: Initialisiere und implementiere das Dateisystem-Handling für das Auslesen und Verwalten von .wav (oder optimiert .raw für Performance) Sample-Dateien.

2. 🔌 MIDI-Erkennung und Kommunikation
MIDI-Erkennung: Die Anwendung muss angeschlossene MIDI-Geräte (insbesondere den Novation Circuit Tracks) über USB-MIDI (falls über einen USB-OTG-Adapter oder USB Host möglich) oder Bluetooth-MIDI (BLE-MIDI) erkennen können, um Befehle zu senden/empfangen.

Gerätespezifische Kommunikation: Implementiere Funktionen, um die Sample-Slots des Circuit Tracks über SysEx-Nachrichten oder spezifische MIDI-Befehle auszulesen und zu beschreiben, analog zur Novation Components-Software.

3. 📂 Sample-Verwaltung (SD-Karte)
Dateibrowser: Erstelle einen Touch-optimierten Dateibrowser, der Samples auf der SD-Karte des CYD anzeigt und es dem Benutzer erlaubt, diese auszuwählen.

Anzeige: Zeige Dateinamen und idealerweise die Wellenform oder eine Vorschau des Samples an.

4. 🖱️ Novation Components UI-Nachbildung
Oberfläche: Gestalte die Touch-Oberfläche so, dass sie die Sample-Slot-Verwaltung der Novation Components-Software für Circuit Tracks widerspiegelt.

Slots: Stelle die 64 Sample-Slots (oder eine überschaubare Untergruppe pro Bildschirm) grafisch dar.

Drag-and-Drop: Dies ist die Kernanforderung. Implementiere eine Funktion, bei der ein ausgewähltes Sample aus dem Dateibrowser per Drag-and-Drop auf einen der grafisch dargestellten Sample-Slots gezogen werden kann. Beim Loslassen (Touch-Up) wird das Sample dem Slot zugeordnet.

5. 💾 Laden und Speichern (Circuit Tracks)
Upload: Wenn ein Sample einem Slot zugewiesen wurde, implementiere eine Funktion (z.B. über einen "Upload"-Button), die das Sample zum Circuit Tracks (via MIDI/SysEx) überträgt und dort in den entsprechenden Slot lädt.

Speichern: Biete eine Möglichkeit, die aktuelle Slot-Zuweisung auf dem Circuit Tracks zu speichern (oder zumindest den Befehl zum Speichern an das Gerät zu senden).

Bestätigung: Implementiere eine visuelle Rückmeldung auf dem CYD, die den Status des Uploads (wird geladen, erfolgreich, Fehler) anzeigt.

🎯 Zusammenfassend:
Der Code soll modular und kommentiert sein. Erkläre kurz die notwendigen Schritte zum Flashen von MicroPython und zur Installation der Bibliotheken auf dem ESP32 CYD. Gehe besonders auf die Herausforderungen der Touch-Eingabe und der MIDI-Kommunikation in MicroPython ein.