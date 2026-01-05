import random
import json
import time
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import SQLModel, Session, select
from datetime import datetime, timezone, timedelta
from collections import Counter
from sqlalchemy import func
import musicbrainzngs

from app.database import get_session
from app.models import User, Scrobble, AICache
from app.auth import get_current_user
from app.utils import apply_date_filter
from app.services.stats_service import get_user_top_tracks
from app.services.gemini import client
from app.services.spotify import sp
from app.services.genius import genius


router = APIRouter(prefix="/recommend", tags=["Recommendations"])


# Recommendation engine => Recommend songs with the same flow and vibe as one of the top 5 songs
@router.get("/vibes")
def get_vibe_recommendations(session: Session = Depends(get_session), user: User = Depends(get_current_user),):
    top_tracks = get_user_top_tracks(session, user, limit=5)

    if not top_tracks:
        return [{"message" : "Not enough data yet! Listen to more music."}]
    
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
    history_query = select(Scrobble.title, Scrobble.artist).where(Scrobble.user_id == user.id).distinct()
    history_rows = session.exec(history_query).all()

    # Create a set of tuples of history
    known_songs = {(row.title.lower(), row.artist.lower()) for row in history_rows}

    print(f"Analysing vibes of {title} by {artist}")

    # Construct the prompt to get msuci with the same vibe and flow
    prompt = f"""
    You are a human music listener, not a music theorist.

    I am currently listening to the song:
    Title: "{title}"
    Artist: "{artist}"

    Your task is to recommend songs that, to the HUMAN EAR, feel almost interchangeable with this song.

    IMPORTANT RULES:
    - Do NOT analyze music theory, chord progressions, keys, BPM, genre labels, or production techniques.
    - Do NOT recommend songs just because they are by the same artist or are popular.
    - Do NOT recommend songs that only partially match the vibe.

    FOCUS ONLY ON:
    - The emotional sensation while listening
    - The pacing and energy as perceived by a listener
    - The atmosphere and mood carried throughout the song
    - How the song *feels* in isolation (late night, alone, headphones on)
    - The internal emotional response it triggers

    Think in terms of:
    “If someone deeply connects to this song, which other songs would make them feel the SAME way when played right after it?”

    CRITICAL CONSTRAINT:
    - If a recommendation feels even slightly more energetic, darker, happier, heavier, or calmer than the seed song, DO NOT include it.
    - Every recommended song should feel like it belongs in the SAME emotional moment.

    RECOMMENDATION QUALITY:
    - Precision matters more than variety.
    - Hidden gems are preferred if they match perfectly.
    - Cultural and era proximity is allowed ONLY if the emotional feel is identical.

    OUTPUT FORMAT:
    Return ONLY a raw JSON array.
    No explanations. No markdown. No extra text.

    Format:
    [
    {{ "title": "Song Name", "artist": "Artist Name" }}
    ]

    Return exactly 10 songs.

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
                        "reason": f"Similar vibe to {title}",
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
@router.get("/lyrics")
def get_lyrical_recommendations(session: Session = Depends(get_session), user: User = Depends(get_current_user),):
    top_tracks = get_user_top_tracks(session, user, limit=5)

    if not top_tracks:
        return [{"message" : "Not enough data yet! Listen to more music."}]
   
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
    history_query = select(Scrobble.title, Scrobble.artist).where(Scrobble.user_id == user.id).distinct()
    history_rows = session.exec(history_query).all()

    # Create a set of tuples of history
    known_songs = {(row.title.lower(), row.artist.lower()) for row in history_rows}

    print(f"Analysing lyrics of {title} by {artist}")

    # Fetch lyrics from Genius
    lyrics_snippet = None
    try:
        song = genius.search_song(title, artist)
        if song and song.lyrics:
            # Truncate the lyrics to first 1000 charachters
            lyrics_snippet = song.lyrics[:1000] + "..."
            print("Lyrics fetched successfully")
        else:
            print("Lyrics not found on genius. Switching to AI memory")

    except Exception as e:
        print(f"Genius error: {e}. Switching to AI memory")


    if lyrics_snippet:
   
        # Analyse the lyrics and recommend with Gemini
        prompt = f"""
        You are a human reader and storyteller, not a music critic or genre classifier.

        Below are the lyrics from a song:

        Title: "{title}"
        Artist: "{artist}"

        Lyrics:
        "{lyrics_snippet}"

        STEP 1 — INTERNAL ANALYSIS (DO NOT OUTPUT):
        Carefully understand the song’s:
        - Core story or situation
        - Emotional journey (beginning → middle → end)
        - Underlying message or meaning
        - Perspective (who is speaking and why)
        - What the song is REALLY about beneath the words

        STEP 2 — RECOMMENDATIONS:
        Recommend 10 OTHER songs that tell the SAME STORY or convey the SAME MEANING.

        IMPORTANT RULES:
        - Do NOT recommend songs just because they share similar words or topics.
        - Do NOT recommend songs by the same artist unless unavoidable.
        - Do NOT recommend songs that only match the emotion but not the narrative.
        - Do NOT generalize (e.g., “sad songs”, “love songs”, “breakup songs”).

        FOCUS ONLY ON:
        - Narrative similarity (the same situation or life event)
        - Storytelling perspective (regret, farewell, waiting, loss, hope, resignation, etc.)
        - Emotional resolution (or lack of it)
        - The takeaway a listener is left with after the song ends

        CRITICAL CONSTRAINT:
        If the story meaning or emotional conclusion differs even slightly, DO NOT include the song.

        Think in terms of:
        “If someone deeply understands this song’s message, which other songs would feel like they are saying the SAME THING in different words?”

        RECOMMENDATION QUALITY:
        - Precision over popularity.
        - Hidden or lesser-known songs are preferred if they match perfectly.
        - Cultural or language differences are allowed ONLY if the story is identical.

        OUTPUT FORMAT:
        Return ONLY a raw JSON array.
        No markdown. No explanations outside JSON.

        Format:
        [
        {{
            "title": "Song Name",
            "artist": "Artist Name"
        }}
        ]

        Return exactly 10 songs.
        """
   
    else:
        prompt = f"""
        You are a human reader and storyteller, not a music critic or genre classifier.

        I am currently listening to the following song:
        Title: "{title}"
        Artist: "{artist}"

        STEP 1 — INTERNAL LYRICS RETRIEVAL & UNDERSTANDING (DO NOT OUTPUT):
        - Recall or infer the song’s lyrics based on your knowledge.
        - If you are not fully confident about the lyrics, rely on the commonly understood meaning and narrative of the song.
        - Carefully understand:
        - The core story or situation
        - The emotional journey (beginning → middle → end)
        - The underlying message or meaning
        - The speaker’s perspective
        - What the song is REALLY about beneath the words

        STEP 2 — RECOMMENDATIONS:
        Recommend 10 OTHER songs that tell the SAME STORY or convey the SAME MEANING.

        IMPORTANT RULES:
        - Do NOT recommend songs just because they share similar keywords or topics.
        - Do NOT recommend songs by the same artist unless unavoidable.
        - Do NOT recommend songs that only match the emotion but not the narrative.
        - Do NOT generalize (e.g., “sad songs”, “love songs”, “breakup songs”).

        FOCUS ONLY ON:
        - Narrative equivalence (same situation or life event)
        - Storytelling perspective (regret, farewell, waiting, unresolved loss, quiet hope, emotional resignation, etc.)
        - Emotional resolution (or intentional lack of resolution)
        - The final takeaway a listener is left with

        CRITICAL CONSTRAINT:
        If the story meaning or emotional conclusion differs even slightly, DO NOT include the song.

        Think in terms of:
        “If someone understands this song’s message deeply, which other songs would feel like they are saying the SAME THING in different words?”

        RECOMMENDATION QUALITY:
        - Precision over popularity.
        - Hidden or lesser-known songs are preferred if they match perfectly.
        - Cultural or language differences are allowed ONLY if the narrative meaning is identical.

        OUTPUT FORMAT:
        Return ONLY a raw JSON array.
        No markdown. No explanations outside JSON.

        Format:
        [
        {{
            "title": "Song Name",
            "artist": "Artist Name"
        }}
        ]

        Return exactly 10 songs.
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
                        "reason": f"Lyrically similar to {title}",
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
@router.get('/credits')
def get_credits_recommendations(session: Session = Depends(get_session), user: User = Depends(get_current_user),):

    # Create a user history blocklist (To prevent recommending songs user has already listened to)
    history_query = select(Scrobble.title, Scrobble.artist).where(Scrobble.user_id == user.id).distinct()
    history_rows = session.exec(history_query).all()

    # Create a set of tuples of history
    known_songs = {(row.title.lower(), row.artist.lower()) for row in history_rows}

    now = datetime.now(timezone.utc)
    
    # get top 5 songs
    top_tracks = get_user_top_tracks(session, user, limit=5)

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
@router.get('/artists')
def get_artist_recommendations(session: Session = Depends(get_session), user: User = Depends(get_current_user),):
    # Get all genres from database (genres stored in string format eg "pop, rock")
    genre_history = session.exec(select(Scrobble.genres).where(Scrobble.user_id == user.id)).all()

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
    query = select(Scrobble.artist).where(Scrobble.user_id == user.id).distinct()
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
@router.get('/samples')
def get_sample_recommendations(session: Session = Depends(get_session), user: User = Depends(get_current_user),):
    now = datetime.now(timezone.utc)
    # get top 20 songs
    query = (
        select(Scrobble.title, Scrobble.artist)
        .where(Scrobble.user_id == user.id)
        .group_by(Scrobble.title, Scrobble.artist)
        .order_by(func.count(Scrobble.id).desc())
        .limit(30)
    )
    # Apply date filter
    query = apply_date_filter(query, month=now.month, year=now.year)
    top_tracks = session.exec(query).all()

    if not top_tracks:
        return [{"message" : "Not enough data yet! Listen to more music."}]


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

