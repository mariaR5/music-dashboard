from fastapi import APIRouter, Depends
from datetime import datetime, timezone, timedelta
from sqlmodel import SQLModel, Session, select
from sqlalchemy import func, extract, BigInteger

from app.database import get_session
from app.models import User, Scrobble
from typing import Optional, List
from app.auth import get_current_user
from app.utils import apply_date_filter

router = APIRouter(prefix='/stats', tags=["Stats"])



@router.get("/today")
def get_today_stats(session: Session = Depends(get_session), user: User = Depends(get_current_user)):
    # Get start of the day
    now = datetime.now(timezone.utc)
    start_of_day = datetime(now.year, now.month, now.day, tzinfo=timezone.utc) # 00:00:00 of today

    # Get Total Plays
    total_plays = session.exec(
        select(func.count(Scrobble.id))
        .where(Scrobble.user_id == user.id)
        .where(Scrobble.created_at >= start_of_day)
    ).one()

    # Get total minutes listened
    total_ms = session.exec(
       select(func.sum(Scrobble.duration_ms))
       .where(Scrobble.user_id == user.id)
       .where(Scrobble.created_at >= start_of_day) 
    ).one()
    total_mins = int((total_ms or 0) / 60000)

    artist_query = (
        select(Scrobble.artist, Scrobble.artist_image, func.count(Scrobble.id).label('count'))
        .where(Scrobble.user_id == user.id)
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


# Get top songs
@router.get("/top-songs")
def get_top_songs(
    month: Optional[int] = None,
    year: Optional[int] = None,
    limit: int = 5,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
    ):
    # Select title, artist, image_url, count(id) as plays from Scrobble 
    # group by title, artist, img_url
    # order by plays desc
    # limit 5
    query = (
        select(Scrobble.title, Scrobble.artist, Scrobble.image_url, func.count(Scrobble.id).label("plays"))
        .where(Scrobble.user_id == user.id)
        .group_by(Scrobble.title, Scrobble.artist, Scrobble.image_url)
        .order_by(func.count(Scrobble.id).desc())
        .limit(limit)
    )

    # Filter query with month and year
    query = apply_date_filter(query, month, year)

    result = session.exec(query).all() # Returns list of top 5 songs

    return [
        {"title": row.title, "artist": row.artist, "img_url": row.image_url, "plays": row.plays}
        for row in result
    ]


# Get top artists
@router.get("/top-artists")
def get_top_artists(
    month: Optional[int] = None,
    year: Optional[int] = None,
    limit: int = 5,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
    ):
    query = (
        select(Scrobble.artist, Scrobble.artist_image, func.count(Scrobble.id).label("plays"))
        .where(Scrobble.user_id == user.id)
        .group_by(Scrobble.artist, Scrobble.artist_image)
        .order_by(func.count(Scrobble.id).desc())
        .limit(limit)
    )
    query = apply_date_filter(query, month, year)

    results = session.exec(query).all()

    return [
        {"artist": row.artist, "artist_image": row.artist_image, "plays": row.plays}
        for row in results
    ]

# Get total plays
@router.get("/total")
def get_total_stats(
    month: Optional[int] = None,
    year: Optional[int] = None,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
    ):

    # Total plays
    query = select(func.count(Scrobble.id)).where(Scrobble.user_id == user.id)
    query = apply_date_filter(query, month, year)
    total_plays = session.exec(query).one()

    # Total minutes
    query = select(func.sum(Scrobble.duration_ms)).where(Scrobble.user_id == user.id)
    query = apply_date_filter(query, month, year)
    total_ms = session.exec(query).one()
    if total_ms is None:
        total_ms = 0

    total_minutes = int(total_ms / 60000)
    return {
        "total_plays": total_plays,
        "total_minutes": total_minutes,
    }
