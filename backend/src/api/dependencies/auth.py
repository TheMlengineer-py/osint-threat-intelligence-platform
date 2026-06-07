"""
Optional JWT bearer token dependency.
Pass `current_user` as a route dependency to require authentication.
In the prototype this is relaxed — full auth can be enabled via settings.
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from src.core.config.settings import settings
from src.core.security.jwt import decode_access_token

bearer = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> str | None:
    """
    Extract and verify the JWT bearer token from the Authorization header.

    In development (DEBUG=True) authentication is skipped and the caller is
    treated as an anonymous analyst. Enable enforcement in production by
    setting DEBUG=False and raising the 401 unconditionally.
    """
    if settings.debug:
        # Prototype mode: bypass authentication for ease of local testing
        return "analyst"

    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    subject = decode_access_token(credentials.credentials)
    if not subject:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return subject
