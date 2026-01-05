from typing import Optional
from sqlalchemy import extract

from app.models import Scrobble

# Apply month, year filters to query
def apply_date_filter(query, month: Optional[int], year: Optional[int]):
    # If month is specified, update the query to filter data where month[created_at] == month
    if month:
        query = query.where(extract('month', Scrobble.created_at) ==  month)
    if year:
        query = query.where(extract('year', Scrobble.created_at) == year)
    return query