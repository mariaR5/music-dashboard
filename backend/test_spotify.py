import os
from dotenv import load_dotenv
import spotipy
from spotipy.oauth2 import SpotifyClientCredentials

# Load secrets from .env
load_dotenv()

print("---------------------------------")
print(f"DEBUG: SPOTIPY_CLIENT_ID: {os.getenv("SPOTIPY_CLIENT_ID")}")
print(f"DEBUG: SPOTIPY_CLIENT_SECRET: {os.getenv("SPOTIPY_CLIENT_SECRET")}")
print("---------------------------------")

try:
    # Create spotify client
    sp = spotipy.Spotify(auth_manager=SpotifyClientCredentials(
        client_id= os.getenv("SPOTIPY_CLIENT_ID"),
        client_secret= os.getenv("SPOTIPY_CLIENT_SECRET"),
    ))

    print("Attempt: Search for Starboy")
    results = sp.search(q="track:Starboy artist:The Weeknd", limit=1)

    track_name = results["tracks"]["items"][0]["name"]
    print(f"Success! Found song: {track_name}")

except Exception as e:
    print("Failure!")
    print(e)
