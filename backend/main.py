import os
import json
import time
import random
import requests
from dotenv import load_dotenv
from fastapi import FastAPI, Depends
from sqlmodel import SQLModel, Session, create_engine, Field, select
from sqlalchemy import func, extract
from typing import Optional, List
from datetime import datetime, timezone
from collections import Counter

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
    duration_ms: int = Field(default=0)
    image_url: Optional[str] = None
    artist_image: Optional[str] = None
    genres: Optional[str] = None

# Table to store AI results
class AICache(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    seed_title: str
    seed_artist: str
    rec_type: str
    data_json: str
    created_at: datetime = Field(default_factory=lambda: datetime.utcnow())


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
@app.get("/history")
def read_history(
    limit: Optional[int] = None,
    session: Session = Depends(get_session)
    ):
    query = select(Scrobble).order_by(Scrobble.id.desc())

    if limit:
        subquery = (
            select(Scrobble.title, Scrobble.artist, func.max(Scrobble.id).label('latest_id'))
            .group_by(Scrobble.title, Scrobble.artist)
            .subquery()
        )
        query = (
            select(Scrobble)
            .join(subquery, Scrobble.id == subquery.c.latest_id)
            .order_by(Scrobble.id.desc())
            .limit(limit)
        )
    
    scrobbles = session.exec(query).all()
    return scrobbles

# Get the track album image
@app.get('/track/image')
def get_track_image(title: str, artist: str):
    data = enrich_data(title, artist)

    if data and 'image_url' in data:
        return {'image_url': data['image_url']}
    
    return {'image_url': None}


#======================================STATS===================================================

# Apply month, year filters to query
def apply_date_filter(query, month: Optional[int], year: Optional[int]):
    # If month is specified, update the query to filter data where month[created_at] == month
    if month:
        query = query.where(extract('month', Scrobble.created_at) ==  month)
    if year:
        query = query.where(extract('year', Scrobble.created_at) == year)
    return query

@app.get("/stats/today")
def get_today_stats(session: Session = Depends(get_session)):
    # Get start of the day
    now = datetime.now(timezone.utc)
    start_of_day = datetime(now.year, now.month, now.day, tzinfo=timezone.utc) # 00:00:00 of today

    # Get Total Plays
    total_plays = session.exec(
        select(func.count(Scrobble.id))
        .where(Scrobble.created_at >= start_of_day)
    ).one()

    # Get total minutes listened
    total_ms = session.exec(
       select(func.sum(Scrobble.duration_ms))
       .where(Scrobble.created_at >= start_of_day) 
    ).one()
    total_mins = int((total_ms or 0) / 60000)

    artist_query = (
        select(Scrobble.artist, Scrobble.artist_image, func.count(Scrobble.id).label('count'))
        .where(Scrobble.created_at >= start_of_day)
        .group_by(Scrobble.artist, Scrobble.artist_image)
        .order_by(func.count(Scrobble.id).desc())
        .limit(1)
    )
    top_artist = session.exec(artist_query).first()

    if not top_artist:
        return {
            'total_plays': 0,
            'minutes_listened': 0,
            'top_artist_name': 'No Data',
            'top_artist_image': None
        }
    
    return {
        'total_plays': total_plays,
        'minutes_listened': total_mins,
        'top_artist_name': top_artist.artist,
        'top_artist_image': top_artist.artist_image
    }


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
def get_total_stats(
    month: Optional[int] = None,
    year: Optional[int] = None,
    session: Session = Depends(get_session)
    ):

    # Total plays
    query = select(func.count(Scrobble.id))
    query = apply_date_filter(query, month, year)
    total_plays = session.exec(query).one()

    # Total minutes
    query = select(func.sum(Scrobble.duration_ms))
    query = apply_date_filter(query, month, year)
    total_ms = session.exec(query).one()
    if total_ms is None:
        total_ms = 0

    total_minutes = int(total_ms / 60000)
    return {
        "total_plays": total_plays,
        "total_minutes": total_minutes,
    }


#=================================RECOMMENDATIONS===========================================

# Recommendation engine => Recommend songs with the same flow and vibe as one of the top 5 songs

client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

@app.get("/recommend/vibes")
def get_vibe_recommendations(session: Session = Depends(get_session)):
    # Get current month and year
    now = datetime.now(timezone.utc)

    # get top 5 songs
    query = (
        select(Scrobble.title, Scrobble.artist)
        .group_by(Scrobble.title, Scrobble.artist)
        .order_by(func.count(Scrobble.id).desc())
        .limit(5)
    )
    
    # Apply date filter
    query = apply_date_filter(query, month=now.month, year=now.year)
    top_tracks = session.exec(query).all()

    if not top_tracks:
        return {"message" : "Not enough data yet! Listen to more music."}
    
    # Choose a random song from top 5 songs
    seed_track = random.choice(top_tracks)
    title, artist = seed_track

    print(f'Checking cache for {title} - {artist}')

    cache_query = select(AICache).where(
        AICache.seed_title == title,
        AICache.seed_artist == artist,
        AICache.rec_type == 'vibes'
    )   
    cached_entry = session.exec(cache_query).first()

    if cached_entry:
        # Check if cache is more than 7 days old
        now = datetime.utcnow()
        age = now - cached_entry.created_at

        if age.days < 7:
            print(f'Found {title} in cache. Returning stored recs')
            return json.loads(cached_entry.data_json)
        else:
            print(f'Cache expired. Regenerating')
            session.delete(cached_entry)
            session.commit()

    print(f'Song details not found in cache')
        
    # Create a user history blocklist (To prevent recommending songs user has already listened to)
    history_query = select(Scrobble.title, Scrobble.artist).distinct()
    history_rows = session.exec(history_query).all()

    # Create a set of tuples of history
    known_songs = {(row.title.lower(), row.artist.lower()) for row in history_rows}

    print(f"Analysing vibes of {title} by {artist}")

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

            # Prevent recommending song user alrady knows
            if (song['title'], song['artist']) in known_songs:
                print(f'User already knows {song['title']}')
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

        # Save song and recommendations to cache
        if recommendations:
            print(f'Saving recommendations to cache')
            new_cache = AICache(
                seed_title=title,
                seed_artist=artist,
                rec_type='vibes',
                data_json=json.dumps(recommendations)
            )
            session.add(new_cache)
            session.commit()

        
        return recommendations

    except Exception as e:
        print(f"AI error: {e}")
        return []
    
# Recommendation engine => Recommend songs with lyrical similarity as one of the top 5 songs

genius = lyricsgenius.Genius(os.getenv("GENIUS_ACCESS_TOKEN"), timeout=15, retries=3)
genius.remove_section_headers = True # Remove headers ([Chorus] [Verse])
genius.verbose = False # Turn off status messages

@app.get("/recommend/lyrics")
def get_lyrical_recommendations(session: Session = Depends(get_session)):
    now = datetime.now(timezone.utc)
    # get top 5 songs
    query = (
        select(Scrobble.title, Scrobble.artist)
        .group_by(Scrobble.title, Scrobble.artist)
        .order_by(func.count(Scrobble.id).desc())
        .limit(5)
    )

    # Apply date filter
    query = apply_date_filter(query, month=now.month, year=now.year)
    top_tracks = session.exec(query).all()

    if not top_tracks:
        return {"message" : "Not enough data yet! Listen to more music."}
    
    # Choose a random song from top 5 songs
    seed_track = random.choice(top_tracks)
    title, artist = seed_track

    print(f'Checking cache for {title} - {artist}')

    cache_query = select(AICache).where(
        AICache.seed_title == title,
        AICache.seed_artist == artist,
        AICache.rec_type == 'lyrics'
    )   
    cached_entry = session.exec(cache_query).first()

    if cached_entry:
        # Check if cache is more than 7 days old
        now = datetime.utcnow()
        age = now - cached_entry.created_at

        if age.days < 7:
            print(f'Found {title} in cache. Returning stored recs')
            return json.loads(cached_entry.data_json)
        else:
            print(f'Cache expired. Regenerating')
            session.delete(cached_entry)
            session.commit()
    
    print(f'Song details not found in cache')
        
    # Create a user history blocklist (To prevent recommending songs user has already listened to)
    history_query = select(Scrobble.title, Scrobble.artist).distinct()
    history_rows = session.exec(history_query).all()

    # Create a set of tuples of history
    known_songs = {(row.title.lower(), row.artist.lower()) for row in history_rows}

    print(f"Analysing lyrics of {title} by {artist}")

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
                
            # Prevent recommending song user alrady knows
            if (song['title'], song['artist']) in known_songs:
                print(f'User already knows {song['title']}')
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

        # Save song and recommendations to cache
        if recommendations:
            print(f'Saving recommendations to cache')
            new_cache = AICache(
                seed_title=title,
                seed_artist=artist,
                rec_type='lyrics',
                data_json=json.dumps(recommendations)
            )
            session.add(new_cache)
            session.commit()
        
        return recommendations

    except Exception as e:
        print(f"AI error: {e}")
        return []


# Recommendation engine => Recommend songs by same producers/songwriters
@app.get('/recommend/credits')
def get_credits_recommendations(session: Session = Depends(get_session)):

    # Create a user history blocklist (To prevent recommending songs user has already listened to)
    history_query = select(Scrobble.title, Scrobble.artist).distinct()
    history_rows = session.exec(history_query).all()

    # Create a set of tuples of history
    known_songs = {(row.title.lower(), row.artist.lower()) for row in history_rows}

    now = datetime.now(timezone.utc)
    
    # get top 5 songs
    query = (
        select(Scrobble.title, Scrobble.artist)
        .group_by(Scrobble.title, Scrobble.artist)
        .order_by(func.count(Scrobble.id).desc())
        .limit(5)
    )
    # Apply date filter
    query = apply_date_filter(query, month=now.month, year=now.year)
    top_tracks = session.exec(query).all()

    if not top_tracks:
        return [{"message" : "Not enough data yet! Listen to more music."}]
    
    # Convert to list and shuffle
    track_candidates = list(top_tracks)
    random.shuffle(track_candidates)

    recommendations = []
    musicbrainzngs.set_useragent("UniversalScrobbler", "1.0", "http://localhost:8000")

    # Iterate through each track until we find a song with songwriter and other works
    for track in track_candidates:
        title, artist = track
        print(f"Credits search for: {title} - {artist}")

        try:
            time.sleep(1.1)

            # Search for recording on MB
            print(f"Searching for {title} - {artist}")
            result = musicbrainzngs.search_recordings(query=title, artist=artist, limit=5)

            if not result['recording-list']:
                print(f'Song not found of MB. Skipping...\n')
                continue

            # Get the first match
            recording = result['recording-list'][0]
            recording_id = recording['id']
            print(f"Found recording {recording['title']} - {recording_id}")

            # Get full recording details (work relationships)
            recording_details = musicbrainzngs.get_recording_by_id(
                id=recording_id,
                includes=['artist-rels', 'work-rels']
            )

            songwriter = None
            work_id = None
            
            # Find the main songwriter
            if 'work-relation-list' in recording_details['recording']:
                for work_rel in recording_details['recording']['work-relation-list']:
                    if 'work' in work_rel:
                        work_id = work_rel['work']['id']
                        print(f'Found work id: {work_id}')

                        work_details = musicbrainzngs.get_work_by_id(work_id, includes=['artist-rels'])

                        if 'artist-relation-list' in work_details['work']:
                            for artist_rel in work_details['work']['artist-relation-list']:
                                rel_type = artist_rel.get('type', '')
                                if rel_type in ['composer', 'writer', 'lyricist']:
                                    songwriter = artist_rel['artist']['name']
                                    songwriter_id = artist_rel['artist']['id']
                                    print(f'Found {rel_type}: {songwriter}')
                                    break
                        
                        if songwriter: break

            if not songwriter:
                print('No songwriter found for this song. Skipping...\n')
                continue
            
            print(f'Finding other works by {songwriter}')

            # Search for other works by the songwriter
            work_result = musicbrainzngs.search_works(artist=songwriter, limit=50)

            songs = []
            seen_songs = set()

            for work in work_result['work-list']:
                work_title = work['title']

                # Skip duplicates
                if work_title in seen_songs or work_title == title:
                    continue
                
                # Get recordings of the work to find the artist of the song
                try:
                    time.sleep(1.1)

                    work_id = work['id']
                    # Get full work details with recording
                    work_detail = musicbrainzngs.get_work_by_id(work_id, includes=['recording-rels'])

                    if 'recording-relation-list' in work_detail['work']:
                        rec_relations = work_detail['work']['recording-relation-list']
                        if rec_relations:
                            # Get the first recordings id
                            recording_id = rec_relations[0].get('recording', {}).get('id')

                            # Use the recording id to get the recording details with artists
                            if recording_id:
                                rec_details = musicbrainzngs.get_recording_by_id(recording_id, includes=['artists'])

                                # Get artist name from full recording details
                                if 'artist-credit' in rec_details['recording']:
                                    artist_name = rec_details['recording']['artist-credit'][0]['artist']['name']
                                else:
                                    artist_name = 'Unknown Artist'

                                print(f'Found match: {work_title} - {artist_name}')

                                # History check
                                if (work_title.lower(), artist_name.lower()) in known_songs:
                                    print(f'User already knows {work_title}')
                                    continue

                                songs.append({
                                    'title': work_title,
                                    'artist': artist_name
                                })
                                seen_songs.add(work_title.lower())

                                if len(songs) >= 5: break
                except:
                    continue

                if len(songs) >= 5: break
            
        except Exception as e:
            continue
        

        # Search spotify for the songs
        if songs:
            print(f'Verifying {len(songs)} candidates on spotify')

            for song in songs:
                if len(recommendations) >= 5: break
                
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
                            "reason": f"Also produced by {songwriter}",
                        })
                
                except Exception as e:
                    print(f"Error finding on spotify: {song['title']} : {e}")
                    continue
        
        if recommendations:
            return recommendations
        else:
            print("Found nothing valid. Retrying next song\n")
    
    return [{'message': 'No credits found for any artists'}]

   
def get_ai_credit_recs(title, artist):
    
    prompt = f"""
    Who is the main producer or songwriter of "{title}" by "{artist}"?
    Identify the most famous one.
    Then, recommend 10 other songs produced or written by that SPECIFIC person.
    
    Return JSON:
    [
        {{"title": "Song", "artist": "Artist", "reason": "Produced by [Name]"}}
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
                        "reason": song['reason']
                    })
            
            except Exception as e:
                print(f"Error in {song['title']} : {e}")
                continue
        
        return recommendations

    except Exception as e:
        print(f"AI error: {e}")
        return []

# Recommendation engine => Recommend new artists based on user's top genres
@app.get('/recommend/artists')
def get_artist_recommendations(session: Session = Depends(get_session)):
    # Get all genres from database (genres stored in string format eg "pop, rock")
    genre_history = session.exec(select(Scrobble.genres)).all()

    if not genre_history:
        return [{'title': 'No data', 'artist': '-', 'reason': 'No history'}]
    
    # Get each genre count
    genre_count = Counter() # To store count of each genre eg {'rock': 2, 'pop': 4}
    for genre_str in genre_history:
        if genre_str:
            # Split the string to get list of indivitual genres
            genres = [g.strip().lower() for g in genre_str.split(',')]
            genre_count.update(genres)

    # Get top 5 genres
    top_genres_tuples = genre_count.most_common(5) # Returns list of tuples eg: [('rock', 2), ('pop', 4)]
    top_genres = [g[0] for g in top_genres_tuples] # List of top genres

    print(f"Top genres: {top_genres}")

    if not top_genres:
        return []
    

    # Build artist blocklist (Already known artists)
    query = select(Scrobble.artist).distinct()
    known_artists = [a.lower() for a in session.exec(query).all()]

    # Dictionary to store candidate artists {artist_id: artist_object}
    candidates = {}

    search_seeds = top_genres[:3]  # Take only top 3 genres

    for genre in search_seeds:
        try:
            # Search for playlists with this genre
            playlist_results = sp.search(q=f'{genre} top artists', type='playlist', limit=3)

            # Check if playlist exists
            if not playlist_results or 'playlists' not in playlist_results:
                print(f'No playlists found for {genre}')
                continue

            for playlist in playlist_results['playlists']['items']:
                if not playlist:  # Skip None playlists
                    continue

                try:
                    # Get tracks from this playlist
                    tracks_result = sp.playlist_tracks(playlist['id'], limit=30)

                    if not tracks_result or 'items' not in tracks_result or not tracks_result['items']:
                        print(f'No tracks found in playlist {playlist.get('name', 'Unknown')}')
                        continue
                    
                    for item in tracks_result['items']:
                        if not item['track']:
                            continue
                    
                        track = item['track']
                        artist = track['artists'][0]
                        artist_name = artist['name']

                        if artist_name.lower() in known_artists or artist['id'] in candidates:
                            continue

                        try:
                            full_artist = sp.artist(artist['id'])

                            if full_artist['popularity'] > 20:
                                candidates[artist['id']] = full_artist
                        except:
                            continue
                    
                    if len(candidates) >= 50: break
                
                except Exception as e:
                    print(f'Error processing playlist: {e}')
                    continue

            if len(candidates) >= 50: break

        except Exception as e:
            print(f"Search error for {genre}: {e}")
            continue

    print(f"Analysing {len(candidates)} candidates")


    # Score candidates (Intersection Logic)
    scored_artists = []

    user_genre_set = set(top_genres) # To perform intersection

    for artist_id, artist_obj in candidates.items():
        cand_genres = set(artist_obj['genres'])

        # Calculate intersection
        overlap = list(cand_genres.intersection(user_genre_set))
        score = len(overlap)

        # If no exact match, try fuzzy matching
        if score == 0:
            overlap = []
            for user_genre in user_genre_set:
                for cand_genre in cand_genres:
                    if user_genre in cand_genre:
                        overlap.append(user_genre)
                        score += 0.5
                        break

        if score > 0:
            scored_artists.append({
                "artist": artist_obj,
                "score": score,
                "overlap": overlap
            })


    # Sort by score (descending)
    scored_artists.sort(key=lambda x: x['score'], reverse=True)

    recommendations = []

    # Take top 10 winners
    for item in scored_artists[:10]:
        artist = item['artist']
        score = item['score']
        shared = ', '.join(item['overlap'])

        recommendations.append({
            'artist': artist['name'],
            'artist_image': artist['images'][0]['url'] if artist['images'] else "",
            'spotify_url': artist['external_urls']['spotify'],
            'reason': f"More artists of {shared}"

        })
    
    return recommendations

# Recommendation engine => Recommend songs sampled from/sampled in users top songs
@app.get('/recommend/samples')
def get_sample_recommendations(session: Session = Depends(get_session)):
    now = datetime.now(timezone.utc)
    # get top 20 songs
    query = (
        select(Scrobble.title, Scrobble.artist)
        .group_by(Scrobble.title, Scrobble.artist)
        .order_by(func.count(Scrobble.id).desc())
        .limit(30)
    )
    # Apply date filter
    query = apply_date_filter(query, month=now.month, year=now.year)
    top_tracks = session.exec(query).all()

    if not top_tracks:
        return {"message" : "Not enough data yet! Listen to more music."}


    recommendations = []
    seen_songs = {t.title.lower() for t in top_tracks}

    for song_entry in top_tracks:
        if len(recommendations) >=5: break

        title, artist = song_entry
        print(f'Checking samples for {title} - {artist}')

        try:
            query = f'{title} {artist}'
            result = genius.search_songs(query) # Get metadata of the song

            if not result or 'hits' not in result or not result['hits']:
                continue
            
            # Get ID of the first search match
            top_hit = result['hits'][0]['result']
            genius_id = top_hit['id']

            print(f'Found genius id: {genius_id}')

            # Fetch full song data of the speicific id
            song_data = genius.song(genius_id)['song']

            # Get song realtionships (returns dict of samples, sampled_in, remixes and covers)
            relations = song_data.get('song_relationships', [])
            target_types = ['samples', 'sampled_by']

            candidates = []

            for relation in relations:
                rel_type = relation['type']

                if rel_type in target_types:
                    for rel_song in relation['songs']:
                        # Extract artist name
                        rel_artist = rel_song.get('artist_names')
                        if not rel_artist and 'primary_artist' in rel_song:
                            rel_artist = rel_song['primary_artist']['name']

                        candidates.append({
                            'title': rel_song['title'],
                            'artist': rel_artist,
                            'type': rel_type
                        })

            if not candidates:
                continue

            random.shuffle(candidates)
            print(f"Found {len(candidates)} sample connectiions")


            for item in candidates:
                if len(recommendations) >= 5: break

                cand_title = item['title']
                cand_artist = item['artist']

                print(f"Processing {cand_title} - {cand_artist}")

                if cand_title.lower() in seen_songs: continue
                if cand_artist.lower() in artist.lower(): continue # Skips remixes by same artist

                try:
                    query = f"track:{cand_title} artist:{cand_artist}"
                    result = sp.search(q=query, type='track', limit=1)

                    if result['tracks']['items']:
                        track = result['tracks']['items'][0]

                        reason = ''
                        if item['type'] == 'samples':
                            reason = f'Sampled in {title}' # Ancestor
                        else:
                            reason = f'Samples from {title}' # Descendant


                        recommendations.append({
                            "title": track['name'],
                            "artist": track['artists'][0]['name'],
                            "image_url": track['album']['images'][0]["url"] if track['album']['images'] else "",
                            "spotify_url": track['external_urls']['spotify'],
                            "reason": reason,
                        })
                        seen_songs.add(cand_title.lower())
                        print(f"Match found: {cand_title} - {cand_artist}")
                    
                    else:
                        print("Not found on spotify")

                except:
                    continue
        
        except Exception as e:
            print(f"Genius Error: {e}")
            return [] 

    return recommendations 


# Health check
@app.get("/") # "/" sending request to root path
def home():
    return {
        "status" : "online",
        "system" : "Music Dashboard Backend"
    }
