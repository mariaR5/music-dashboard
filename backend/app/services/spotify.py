import os
from dotenv import load_dotenv

import spotipy
from spotipy.oauth2 import SpotifyClientCredentials

load_dotenv()

# Create spotify client
sp = spotipy.Spotify(auth_manager=SpotifyClientCredentials(
    client_id= os.getenv("SPOTIPY_CLIENT_ID"),
    client_secret= os.getenv("SPOTIPY_CLIENT_SECRET"),
))

# Documentation : https://developer.spotify.com/documentation/web-api
def enrich_data(title: str, artist: str):
    print(f"Searching Spotify for {title} - {artist}")

    try:
        # Search for the track on spotify
        query = f"track:{title} artist:{artist}" # Spotify query
        results = sp.search(q=query, type="track", limit=1) # Returns track type dictonary with top search

        items = results["tracks"]["items"]

        # Return empty dictionary if song is not found (ie; items contains nothing)
        if not items:
            print("Song not found on Spotify")
            return {}
        
        track = items[0] # Gets the first and only dict in items list
        t_id = track["id"] # Stores spotify id of the track


        artist_id = track["artists"][0]["id"]
        artist_info = sp.artist(artist_id)
        artist_image = artist_info["images"][0]["url"]
        genre_list = artist_info["genres"] # Returns a list of genres

        return {
            "spotify_id": t_id,
            "duration_ms": track['duration_ms'],
            "image_url": track["album"]["images"][0]["url"],
            "artist_image": artist_image,
            "tempo": None, # features["tempo"],
            "valence": None, # features["valence"],
            "energy": None, # features["energy"],
            "genres": ", ".join(genre_list) # Convert list to string
        }

    except Exception as e:
        print(f"Error talking to Spotify: {e}")
        return {}
