import os
import random
import requests
from dotenv import load_dotenv
from fastapi import FastAPI, Depends
from sqlmodel import SQLModel, Session, create_engine, Field, select
from sqlalchemy import func, extract
from typing import Optional, List
from datetime import datetime, timezone
import spotipy
from spotipy.oauth2 import SpotifyClientCredentials

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


# Recommendation engine => Recommend random songs that match the top artist's genre


# Helper to get tags from lastfm
def get_track_tags(artist: str, track: str):
    api_key = os.getenv("LASTFM_API_KEY")

    if not api_key:
        print("No Last.fm api key found")
        return []
    
    # Documentation : https://www.last.fm/api
    url = "http://ws.audioscrobbler.com/2.0" # API endpoint
    params = {
        "method" : "track.getTopTags",
        "track" : track,
        "artist": artist,
        "api_key" : api_key,
        "autocorrect" : 1,
        "format" : "json"
    }

    try:
        response = requests.get(url, params=params)
        data = response.json()

        # Check if toptags or tags exists
        raw_tags = data.get("toptags", {}).get("tag", [])

        clean_tags = []

        # Common irrelevant tags
        BLACKLIST = {
            "seen live", "favorites", "favourite", "love", "liked",
            "songs i love", "my favourites", "cool", "awesome",
            "under 2000 listeners", "under 5000 listeners", "over 1000 listeners",
            "playlist", "my playlist", "on repeat", "saved",
            "spotify", "lastfm", "youtube", "mp3",
            "good", "nice", "random"
        }

        # Filter out irrelevant tags
        for tag in raw_tags:
            tag_name = tag["name"].lower()

            if tag_name in BLACKLIST or tag_name == artist.lower():
                continue
            clean_tags.append(tag_name)
        
        return clean_tags[:5] # Return top 5 tags
    
    except Exception as e:
        print(f"Last.fm error: {e}")
        return []


# Helper to get tracks with given tags
def get_track_by_tags(tag: str):
    api_key = os.getenv("LASTFM_API_KEY")

    if not api_key:
        print("No Last.fm api key found")
        return []
    
    url = "http://ws.audioscrobbler.com/2.0" # API endpoint
    params = {
        "method" : "tag.getTopTracks",
        "tag" : tag,
        "api_key" : api_key,
        "format" : "json",
        "limit" : 50
    }

    try:
        response = requests.get(url, params=params)
        data = response.json()
        tracks = data.get("toptracks", {}).get("track", [])

        return [{"name" : track["name"], "artist" : track["artist"]["name"]} for track in tracks]

    except Exception as e:
        print(f"Last.fm Tag Search Error {e}")
        return []
    

# Recommendation engine => Recommend songs with the same last fm tags as the top songs
@app.get("/recommend")
def get_recommendations(session: Session = Depends(get_session)):
    # get top song
    query = (
        select(Scrobble.title, Scrobble.artist)
        .group_by(Scrobble.title, Scrobble.artist)
        .order_by(func.count(Scrobble.id).desc())
        .limit(1)
    )
    top_track = session.exec(query).first()

    if not top_track:
        print("Cant get top track")
        return []
    
    title, artist = top_track
    tags = get_track_tags(artist, title)

    if not tags:
        print("Cant get tags")
        return []
    
    # Pick the first valid tag (for now)
    selected_tag = tags[0]
    print(f"Tag selected: {selected_tag}")

    # Get songs with matching tags
    candidate_songs = get_track_by_tags(selected_tag)
    print(candidate_songs)

    # List to store recommended songs
    recommendations = []

    for song in candidate_songs:
        # Dont recommend the same song
        if song["name"].lower() == title.lower():
            continue

        try:
            # Search spotify for track
            query = f"track:{song['name']} artist:{song['artist']}"
            result = sp.search(q=query, type='track', limit=1)

            items = result['tracks']['items']
            if items:
                track = items[0]
                recommendations.append({
                    "title": track["name"],
                    "artist": track["artists"][0]["name"],
                    "image_url": track["album"]["images"][0]["url"],
                    "external_url": track["external_urls"]["spotify"],
                    "reason": f"Because you listened to {selected_tag} music"

                })
        
        except Exception as e:
            continue
        
        # Recommend max of 10 recommendations
        if len(recommendations) >= 10:
            break
    

    return recommendations
    

# Health check
@app.get("/") # "/" sending request to root path
def home():
    return {
        "status" : "online",
        "system" : "Music Dashboard Backend"
    }
