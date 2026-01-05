from datetime import datetime, timezone, timedelta
from sqlmodel import SQLModel, Session, select
from sqlalchemy import func, extract, BigInteger

from app.models import User, Scrobble

def get_user_top_tracks(session: Session, user: User, limit: int = 5):
    now = datetime.now(timezone.utc)
    start_date = None

    # If period is only present month, start date is 1st of this month
    if user.rec_period == 0:
        start_date = datetime(now.year, now.month, 1, tzinfo=timezone.utc)
    # Else start date is X months ago
    else:
        start_date = now - timedelta(days=user.rec_period * 30)

    print(f"Filtering recommendations from: {start_date}")

    query = (
        select(Scrobble.title, Scrobble.artist)
        .where(Scrobble.user_id == user.id)
        .where(Scrobble.created_at >= start_date)
        .group_by(Scrobble.title, Scrobble.artist)
        .order_by(func.count(Scrobble.id).desc())
        .limit(limit)
    )

    return session.exec(query).all()