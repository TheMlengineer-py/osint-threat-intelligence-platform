"""
Security Manager for Authentication
"""

from src.core.security.jwt import create_access_token, verify_token


class SecurityManager:
    """Handles security operations"""

    @staticmethod
    def create_access_token(data: dict, expires_delta=None):
        """Create JWT token"""
        return create_access_token(data, expires_delta)

    @staticmethod
    def verify_token(token: str):
        """Verify JWT token"""
        return verify_token(token)
