import os
import lyricsgenius
from dotenv import load_dotenv

load_dotenv()

# Initialize the client
genius = lyricsgenius.Genius(os.getenv("GENIUS_ACCESS_TOKEN"), timeout=15, retries=3)

# Global Settings
genius.remove_section_headers = True # Remove headers ([Chorus] [Verse])
genius.verbose = False # Turn off status messages