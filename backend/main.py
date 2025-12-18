import os
import json
import random
from dotenv import load_dotenv
from fastapi import FastAPI, Depends
from sqlmodel import SQLModel, Session, create_engine, Field, select
from sqlalchemy import func, extract
from typing import Optional, List
from datetime import datetime, timezone
import spotipy
from spotipy.oauth2 import SpotifyClientCredentials
import google.genai as genai
import lyricsgenius
import musicbrainzngs

# Load secrets from .env
load_dotenv()

# print("---------------------------------")
# print(f"DEBUG: SPOTIPY_CLIENT_ID: {os.getenv("SPOTIPY_CLIENT_ID")}")
# print(f"DEBUG: SPOTIPY_CLIENT_SECRET: {os.getenv("SPOTIPY_CLIENT_SECRET")}")
# print("---------------------------------")

# Create spotify client
sp = spotipy.Spotify(auth_manager=SpotifyClientCredentials(
    client_id= os.getenv("SPOTIPY_CLIENT_ID"),
    client_secret= os.getenv("SPOTIPY_CLIENT_SECRET"),
))

# Setup the database
sqllite_file_name = "music.db" # database name
sqllite_url = f"sqlite:///{sqllite_file_name}" # database url

# Create engine -> responsible for database connection
engine = create_engine(sqllite_url)

# Define the table
class Scrobble(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    title: str
    artist: str
    package: str
    timestamp: int
    # Time server recieved data
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    # Spotify data
    spotify_id: Optional[str] = None
    image_url: Optional[str] = None
    artist_image: Optional[str] = None
    tempo: Optional[float] = None
    valence: Optional[float] = None
    energy: Optional[float] = None
    genres: Optional[str] = None

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

        # features = sp.audio_features([t_id])[0] # Deprecated

        artist_id = track["artists"][0]["id"]
        artist_info = sp.artist(artist_id)
        artist_image = artist_info["images"][0]["url"]
        genre_list = artist_info["genres"] # Returns a list of genres

        return {
            "spotify_id": t_id,
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


# Initialise a server
app = FastAPI()

# Runs when server 'starts', creates all tables in SQLModel metadata
@app.on_event("startup")
def on_startup():
    SQLModel.metadata.create_all(engine)

# Helper function to get db session
def get_session():
    with Session(engine) as session:
        yield session

# Handle request endpoint
class ScrobbleRequest(SQLModel):
    title: str
    artist: str
    package: str
    timestamp: int    

# Create POST endpoint (reciever)
@app.post("/scrobble")
async def receive_scrobble(req: Scrobble, session: Session = Depends(get_session)): # Dependancy Injection
    print(f"Recieved: {req.title} by {req.artist}")

    spotify_data = enrich_data(req.title, req.artist)

    new_scrobble = Scrobble(
        title=req.title,
        artist=req.artist,
        package=req.package,
        timestamp=req.timestamp,
        # Unpack spotify data 
        **spotify_data
    )

    # Save to database
    session.add(new_scrobble)
    session.commit()
    session.refresh(new_scrobble)

    return {
        "status": "success",
        "data": new_scrobble
    }

# See history : Defines http GET endpoint
@app.get("/history", response_model=List[Scrobble])
def read_history(session: Session = Depends(get_session)):
    scrobbles = session.exec(
        select(Scrobble).order_by(Scrobble.id.desc())
    ).all()
    return scrobbles

#---------STATS-----------

# Apply month, year filters to query
def apply_date_filter(query, month: Optional[int], year: Optional[int]):
    # If month is specified, update the query to filter data where month[created_at] == month
    if month:
        query = query.where(extract('month', Scrobble.created_at) ==  month)
    if year:
        query = query.where(extract('year', Scrobble.created_at) == year)
    return query

# Get top 5 songs
@app.get("/stats/top-songs")
def get_top_songs(
    month: Optional[int] = None,
    year: Optional[int] = None,
    session: Session = Depends(get_session)
    ):
    # Select title, artist, image_url, count(id) as plays from Scrobble 
    # group by title, artist, img_url
    # order by plays desc
    # limit 5
    query = (
        select(Scrobble.title, Scrobble.artist, Scrobble.image_url, func.count(Scrobble.id).label("plays"))
        .group_by(Scrobble.title, Scrobble.artist, Scrobble.image_url)
        .order_by(func.count(Scrobble.id).desc())
        .limit(5)
    )

    # Filter query with month and year
    query = apply_date_filter(query, month, year)

    result = session.exec(query).all() # Returns list of top 5 songs

    return [
        {"title": row.title, "artist": row.artist, "img_url": row.image_url, "plays": row.plays}
        for row in result
    ]


# Get top 5 artists
@app.get("/stats/top-artists")
def get_top_artists(
    month: Optional[int] = None,
    year: Optional[int] = None,
    session: Session = Depends(get_session)
    ):
    query = (
        select(Scrobble.artist, Scrobble.artist_image, func.count(Scrobble.id).label("plays"))
        .group_by(Scrobble.artist)
        .order_by(func.count(Scrobble.id).desc())
        .limit(5)
    )
    query = apply_date_filter(query, month, year)

    results = session.exec(query).all()

    return [
        {"artist": row.artist, "artist_image": row.artist_image, "plays": row.plays}
        for row in results
    ]

# Get total plays
@app.get("/stats/total")
def get_total_plays(
    month: Optional[int] = None,
    year: Optional[int] = None,
    session: Session = Depends(get_session)
    ):
    query = select(func.count(Scrobble.id))
    query = apply_date_filter(query, month, year)

    result = session.exec(query).one()
    return {"total_plays": result}


# Recommendation engine => Recommend songs with the same flow and vibe as the top song
# Integrates Gemini API

client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

@app.get("/recommend")
def get_recommendations(session: Session = Depends(get_session)):
    # get top artist
    query = (
        select(Scrobble.title, Scrobble.artist)
        .group_by(Scrobble.title, Scrobble.artist)
        .order_by(func.count(Scrobble.id).desc())
        .limit(1)
    )
    top_track = session.exec(query).first()

    if not top_track:
        return {"message" : "Not enough data yet! Listen to more music."}
    
    title, artist = top_track
    print(f"Analysing vibe for {title} by {artist}")

    # Construct the prompt to get msuci with the same vibe and flow
    prompt = f"""
    I am listening to the song "{title}" by "{artist}".
    
    Please recommend 10 other songs that have the EXACT same vibe, mood, and musical flow.
    Focus on the emotional feeling and tempo.
    Do not just recommend popular hits; include some hidden gems if they fit the vibe perfectly.
    
    Return ONLY a raw JSON list with no markdown formatting. 
    Format:
    [
      {{"title": "Song Name", "artist": "Artist Name"}}
    ]
    """

    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt
        )

        # Reponse may contain ```json .... ```
        text_response = response.text.replace("```json", "").replace("```", "").strip()
        ai_recommendations = json.loads(text_response)
        print(ai_recommendations)

        # List to store final recommendations
        recommendations = []

        for song in ai_recommendations:
            # Skip if it recommends same song
            if song['title'].lower() == title.lower():
                continue

            try:
                query = f"track:{song['title']} artist:{song['artist']}"
                result = sp.search(q=query, type='track', limit=1)

                items = result['tracks']['items']
                if items:
                    track = items[0]
                    recommendations.append({
                        "title": track['name'],
                        "artist": track['artists'][0]['name'],
                        "image_url": track['album']['images'][0]["url"] if track['album']['images'] else "",
                        "spotify_url": track['external_urls']['spotify'],
                        "reason": f"Because you listened to {title}",
                    })
            
            except Exception as e:
                print(f"Error in {song['title']} : {e}")
                continue
        
        return recommendations

    except Exception as e:
        print(f"AI error: {e}")
        return []
    
# Recommendation engine => Recommend songs with lyrical similarity as the top song
genius = lyricsgenius.Genius(os.getenv("GENIUS_ACCESS_TOKEN"), timeout=15, retries=3)
genius.remove_section_headers = True # Remove headers ([Chorus] [Verse])
genius.verbose = False # Turn off status messages

@app.get("/recommend/lyrics")
def get_lyrical_recommendations(session: Session = Depends(get_session)):
    print("Started lyrical analysis engine")

    # get top song
    query = (
        select(Scrobble.title, Scrobble.artist)
        .group_by(Scrobble.title, Scrobble.artist)
        .order_by(func.count(Scrobble.id).desc())
        .limit(1)
    )
    top_track = session.exec(query).first()

    if not top_track:
        return {"message" : "Not enough data yet! Listen to more music."}
    
    title, artist = top_track
    print(f"Analysing lyrics for {title} - {artist}")

    # Fetch lyrics from Genius
    try:
        song = genius.search_song(title, artist)
        if not song:
            print("Lyrics not found on genius")
            return []
        
        lyrics = song.lyrics

        # Truncate the lyrics to first 1000 charachters
        lyrics_snippet = lyrics[:1000] + "..."
        print("Lyrics fetched successfully")

    except Exception as e:
        print(f"Genius error: {e}")
        return []
    
    # Analyse the lyrics and recommend with Gemini
    prompt = f"""
    Here are the lyrics to "{title}" by "{artist}":
    
    "{lyrics_snippet}"
    
    Step 1: Analyze the deep meaning, story, emotional tone, and narrative of these lyrics.
    Step 2: Recommend 10 OTHER songs that share this specific LYRICAL THEME or STORY.
    (Do not just recommend songs by the same artist or genre. Focus on the words/message).
    
    Return ONLY a raw JSON list. Format:
    [
      {{
        "title": "Song Name", 
        "artist": "Artist Name", 
        "reason": "Explain the lyrical connection (e.g. 'Both songs are about the grief of losing a father...')" 
      }}
    ]
    """

    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt
        )

        # Reponse may contain ```json .... ```
        text_response = response.text.replace("```json", "").replace("```", "").strip()
        ai_recommendations = json.loads(text_response)
        print(ai_recommendations)

        # List to store final recommendations
        recommendations = []

        for song in ai_recommendations:
            # Skip if it recommends same song
            if song['title'].lower() == title.lower():
                continue

            try:
                query = f"track:{song['title']} artist:{song['artist']}"
                result = sp.search(q=query, type='track', limit=1)

                items = result['tracks']['items']
                if items:
                    track = items[0]
                    recommendations.append({
                        "title": track['name'],
                        "artist": track['artists'][0]['name'],
                        "image_url": track['album']['images'][0]["url"] if track['album']['images'] else "",
                        "spotify_url": track['external_urls']['spotify'],
                        "reason": f"Because you listened to {title}",
                    })
            
            except Exception as e:
                print(f"Error in {song['title']} : {e}")
                continue
        
        return recommendations

    except Exception as e:
        print(f"AI error: {e}")
        return []


# Recommendation engine => Recommend songs by same producers/songwriters
musicbrainzngs.set_useragent("UniversalScrobbler", "1.0", "http://localhost:8000")

@app.get('/recommend/credits')
def get_credits_recommendations(session: Session = Depends(get_session)):
    # get top song
    query = (
        select(Scrobble.title, Scrobble.artist)
        .group_by(Scrobble.title, Scrobble.artist)
        .order_by(func.count(Scrobble.id).desc())
        .limit(1)
    )
    top_track = session.exec(query).first()

    if not top_track:
        return {"message" : "Not enough data yet! Listen to more music."}
    
    title, artist = top_track
    print(f"Fetching top producer of {title} - {artist}")

    recommendations = []
    seen_songs = {title.lower()}
    top_producer = None

    try:
        rec_search = musicbrainzngs.search_recordings(query=title, artist=artist, limit=3)

        if rec_search.get('recording-list'):
            for rec_match in rec_search['recording-list']:
                mbid = rec_match["id"] # MBID of top track
                try:
                    # Get music data including artist relations (producer, composer, guitarist,...)
                    data = musicbrainzngs.get_recording_by_id(mbid, includes=['artist-rels'])
                    recording = data['recording']

                    # Get direct recording relations (Producers, arranger, ...)
                    for rel in recording.get('artist-relation-list',[]):
                        # Look for producer
                        if rel.get('type') == 'producer':
                            top_producer = (rel['artist']['name'], rel['artist']['id'])
                            break # We only need one producer

                    if top_producer:
                        break

                except:
                    continue
        
        if not top_producer:
            print("No producer found in MusicBrainz")
            return []

        prod_name, prod_id = top_producer
        print(f"Main producer found: {prod_name}")
        
        # Find other songs produced by top producer
        # Fetch artist and recording relations
        artist_data = musicbrainzngs.get_artist_by_id(prod_id, includes=['recording-rels'])
        relations = artist_data['artist'].get('recording-relation-list', [])

        print(f"Found {len(relations)} tracks produced by {prod_name}")

        for rel in relations:
            # Only consider tracks they 'produced'
            if rel.get('type') != 'producer':
                continue

            rec_title = rel['recording']['title']

            # Skip duplicates
            if rec_title.lower() in seen_songs:
                continue

            # Fetch the artist of the song
            try:
                rec_id = rel['recording']['id']
                rec_details = musicbrainzngs.get_recording_by_id(rec_id, includes=['artist-credits'])

                if 'artist-credit' in rec_details['recording']:
                    rec_artist = rec_details['recording']['artist-credit'][0]['artist']['name']
                else:
                    continue

            except:
                continue
            
            print(f"Found match: {rec_title} - {rec_artist}")
            
            # Find song on spotify
            try:
                query = f"track:{rec_title} artist:{rec_artist}"
                result = sp.search(q=query, type='track', limit=1)

                if result['tracks']['items']:
                    track = result['tracks']['items'][0]

                    recommendations.append({
                    "title": track['name'],
                    "artist": track['artists'][0]['name'],
                    "image_url": track['album']['images'][0]["url"] if track['album']['images'] else "",
                    "spotify_url": track['external_urls']['spotify'],
                    "reason": f"Produced by {prod_name})",
                    })
                    seen_songs.add(rec_title.lower())
            except Exception as e:
                print(f"Spotify lookup failed for {rec_title}: {e}")
                pass
            
            if len(recommendations) >= 10: break
        
        return recommendations

    except Exception as e:
        print(f"MusicBrainz error : {e}")
        return []  
    

# Health check
@app.get("/") # "/" sending request to root path
def home():
    return {
        "status" : "online",
        "system" : "Music Dashboard Backend"
    }
