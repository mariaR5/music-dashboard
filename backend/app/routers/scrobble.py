from fastapi import APIRouter, Depends
from sqlmodel import Session, select, delete
from sqlalchemy import func
from typing import Optional

from app.models import Scrobble, User
from app.database import get_session
from app.auth import get_current_user
from app.services.spotify import enrich_data

router = APIRouter(prefix='/scrobble', tags=["Scrobble"])

@router.post('')
async def receive_scrobble(
    req: Scrobble, 
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user)
): # Dependancy Injection
    print(f"Recieved: {req.title} by {req.artist}")

    spotify_data = enrich_data(req.title, req.artist)

    if not spotify_data:
        print(f"{req.title} not found on Spotify. Skipping database save")
        return {
            'status': 'Skipped',
            'message': 'Song not found on Spotify'
        }

    new_scrobble = Scrobble(
        user_id=user.id,
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
@router.get("/history")
def read_history(
    limit: Optional[int] = None,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    query = select(Scrobble).where(Scrobble.user_id == user.id).order_by(Scrobble.id.desc())

    if limit:
        subquery = (
            select(Scrobble.title, Scrobble.artist, func.max(Scrobble.id).label('latest_id'))
            .where(Scrobble.user_id == user.id)
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
@router.get('/track/image')
def get_track_image(title: str, artist: str, user: User = Depends(get_current_user)):
    data = enrich_data(title, artist)

    if data and 'image_url' in data:
        return {'image_url': data['image_url']}
    
    return {'image_url': None}

# Delete history
@router.delete('/history/clear')
def clear_history(user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    query = delete(Scrobble).where(Scrobble.user_id == user.id)
    session.exec(query)
    session.commit()
    return {'message': 'History cleared successfully'}