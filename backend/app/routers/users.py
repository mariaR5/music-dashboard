from fastapi import APIRouter, Depends
from sqlmodel import Session, delete

from app.models import User, PreferenceUpdate, Scrobble
from app.auth import get_current_user
from app.database import get_session


router = APIRouter(prefix="/users", tags=["Users"])

@router.get('/me')
def read_users_me(user: User = Depends(get_current_user)):
    return user

@router.put('/preferences')
def update_preferences(pref: PreferenceUpdate, session: Session = Depends(get_session), user: User = Depends(get_current_user)):
    user.rec_period = pref.rec_period
    session.add(user)
    session.commit()
    return {'message': 'Preference updated', 'rec-period': user.rec_period}

@router.delete('/me')
def delete_account(user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    session.exec(delete(Scrobble).where(Scrobble.user_id == user.id))

    session.delete(user)
    session.commit()
    return {'message': 'Account deleted successfully'}