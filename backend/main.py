import os
import random
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
@app.get("/recommend")
def get_recommendations(session: Session = Depends(get_session)):
    # get top artist
    query = (
        select(Scrobble.artist)
        .group_by(Scrobble.artist)
        .order_by(func.count(Scrobble.id)
        .desc()).limit(1)
    )
    top_artist_name = session.exec(query).first()

    if not top_artist_name:
        return {"message" : "Not enough data yet! Listen to more music."}
    
    try:
        # Search for the artist and get artist id
        search = sp.search(q=f"artist:{top_artist_name}", type="artist", limit=1)
        if not search['artists']['items']:
            return []
        
        top_artist_genres = search['artists']['items'][0]['genres']

        if not top_artist_genres:
            return {"message" : f"No genres found for {top_artist_name} on Spotify"}
        
        seed_genre = top_artist_genres[0]

        offset = random.randint(0, 50)

        # Search spotify for 10 tracks with specified genre (starting from offset position)
        recs = sp.search(q=f'genre:{seed_genre}', type='track', limit=10, offset=offset)

        # List to store recommended songs
        recommendations = []

        # Get the top track by each related artist -> add to list
        for track in recs['tracks']['items']:
            # Dont recommend artist we already listen to
            if track['artists'][0]['name'] == top_artist_name:
                continue

            recommendations.append({
                "title": track["name"],
                "artist": track["artists"][0]["name"],
                "image_url": track["album"]["images"][0]["url"],
                "reason": f"Because you listened to {seed_genre}"

            })
        
        return recommendations
    except Exception as e:
        print(f"Recommendation Error")
        return []
    

# Health check
@app.get("/") # "/" sending request to root path
def home():
    return {
        "status" : "online",
        "system" : "Music Dashboard Backend"
    }
