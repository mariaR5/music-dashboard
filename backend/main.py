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
    print(f"Credits search for: {title} - {artist}")

    recommendations = []
    seen_songs = {title.lower()}
    target_person = None

    musicbrainzngs.set_useragent("UniversalScrobbler", "1.0", "http://localhost:8000")

    try:
        #----Search for key person---

        # Case 1: Search recording for producer
        rec_search = musicbrainzngs.search_recordings(query=title, artist=artist, limit=3)

        if rec_search.get('recording-list'):
            for rec_match in rec_search['recording-list']:
                mbid = rec_match["id"] # MBID of top track
                try:
                    time.sleep(1.1)

                    # Get music data including artist and work relations
                    data = musicbrainzngs.get_recording_by_id(mbid, includes=['artist-rels', 'releases', 'work-rels', 'work-level-rels'])
                    recording = data['recording']

                    # Check producers
                    for rel in recording.get('artist-relation-list', []):
                        if rel.get('type') == 'producer':
                            target_person = (rel['artist']['name'], rel['artist']['id'], "Producer")
                            break
                        if target_person: break


                    # Check writers
                    if 'work-relation-list' in recording:
                        for work_rel in recording['work-relation-list']:
                            if 'work' in work_rel and 'artist-relation-list' in work_rel['work']:
                                for rel in work_rel['work']['artist-relation-list']:
                                    if rel.get('type') in ['composer', 'writer']:
                                        target_person = (rel['artist']['name'], rel['artist']['id'], 'Writer')
                                        break
                                    
                            if target_person: break
                    if target_person: break

                except Exception as e:
                    print(f"Error checking candidates: {e}")
                    continue
        
        if not target_person:
            # Fallback to AI if Musicbrainz fail
            print("No writer/produer found in MusicBrainz. Switching to AI")
            return get_ai_credit_recs(title, artist)

        p_name, p_id, p_role = target_person
        print(f"Target person: {p_name} ({p_role})")

        #---Find other songs by key person---
        time.sleep(1.1)
        includes = ['recording-rels'] if "Producer" in p_role else ['work-rels']
        artist_data = musicbrainzngs.get_artist_by_id(p_id, includes=includes)
        artist_obj = artist_data['artist']
        
        # List to store song candidates
        candidates = []

        if "Producer" in p_role:
            for rel in artist_obj.get('recording-relation-list', []):
                if rel.get('type') in ['producer', 'remixer']:
                    candidates.append((rel['recording']['title'], rel['recording']['id'], 'recording'))

        else:
            for rel in artist_obj.get('work-relation-list', []):
                if rel.get('type') in ['composer', 'writer']:
                    candidates.append((rel['work']['title'], rel['work']['id'], 'work')) 

        # Shuffle and take a smaller slice
        random.shuffle(candidates)
        candidates = candidates[:15]


        for title, id, type in candidates:
            if len(recommendations) >= 10: break
            if title.lower() in seen_songs: continue

            target_performer = None

            try:
                time.sleep(1.1)

                if type == 'recording':
                    rec_data = musicbrainzngs.get_recording_by_id(id, includes=['artist-credits'])
                    if 'artist-credit' in rec_data['recording']:
                        target_performer = rec_data['recording']['artist-credit'][0]['artist']['name']
                elif type == 'work':
                    work_data = musicbrainzngs.get_work_by_id(id, includes=['recording-rels'])
                    if 'recording-relation-list' in work_data['work']:
                        for rel in work_data['work']['recording-relation-list']:
                            if 'artist-credit' in rel['recording']:
                                target_performer = rec_data['recording']['artist-credit'][0]['artist']['name']
                                break
            
            except Exception as e:
                print(f"API rate limit hit/error: {e}")
                continue

            if not target_performer: continue
            
            try:
                # Search spotify for artist of the song
                query = f"track:{title} artist:{target_performer}"
                result = sp.search(q=query, type='track', limit=1)

                if result['tracks']['items']:
                    track = result['tracks']['items'][0]

                    recommendations.append({
                    "title": track['name'],
                    "artist": track['artists'][0]['name'],
                    "image_url": track['album']['images'][0]["url"] if track['album']['images'] else "",
                    "spotify_url": track['external_urls']['spotify'],
                    "reason": f"{p_role}: {p_name}",
                    })
                    seen_songs.add(title.lower())
                    print(f"Recommended: {track['name']}")

            except Exception as e:
                print(f"Spotify lookup failed for {title}: {e}")
                pass
        
        if not recommendations:
            print("No valid credits found")
            return get_ai_credit_recs(title, artist)
        
        return recommendations

    except Exception as e:
        print(f"MusicBrainz error : {e}")
        return []  
    
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
            query = f"genre:{genre}"
            results = sp.search(q=query, type='artist', limit=20)

            for item in results['artists']['items']:
                artist_name = item['name']

                # Skip if known artist
                if artist_name.lower() in known_artists:
                    continue
                
                # Add to candidiate pool
                candidates[item['id']] = item

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
        overlap = cand_genres.intersection(user_genre_set)
        score = len(overlap)

        if score > 0:
            scored_artists.append({
                "artist": artist_obj,
                "score": score,
                "overlap": list(overlap)
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

@app.get('/recommend/samples')
def get_sample_recommendations(session: Session = Depends(get_session)):
    # get top 20 songs
    query = (
        select(Scrobble.title, Scrobble.artist)
        .group_by(Scrobble.title, Scrobble.artist)
        .order_by(func.count(Scrobble.id).desc())
        .limit(30)
    )
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
                    else:
                        print("Not found on spotify")

                        reason = ''
                        if item['type'] == 'samples':
                            reason = f'Sampled by {title}' # Ancestor
                        else:
                            reason = f'Samples {title}' # Descendant


                        recommendations.append({
                            "title": track['name'],
                            "artist": track['artists'][0]['name'],
                            "image_url": track['album']['images'][0]["url"] if track['album']['images'] else "",
                            "spotify_url": track['external_urls']['spotify'],
                            "reason": reason,
                        })
                        seen_songs.add(cand_title.lower())
                        print(f"Match found: {cand_title} - {cand_artist}")

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
