"""Application configuration."""
from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Database
    database_url: str
    database_test_url: str = ""

    # API Security
    api_secret_key: str
    api_algorithm: str = "HS256"
    api_access_token_expire_minutes: int = 10080

    # Gmail API
    gmail_credentials_file: str = "credentials.json"
    gmail_token_file: str = "token.json"

    # App Settings
    app_name: str = "Rechnungsgenerator Imkerei"
    app_version: str = "1.0.0"
    debug: bool = False
    allowed_origins: str = "http://localhost:3000"

    # Invoice Settings
    invoice_number_prefix: str = "RE"
    invoice_number_start: int = 1000
    default_tax_rate: float = 19.0
    default_payment_terms: int = 14

    # File Storage
    upload_dir: str = "./uploads"
    pdf_dir: str = "./pdfs"
    logo_dir: str = "./logos"

    @property
    def cors_origins(self) -> List[str]:
        """Get CORS origins as list."""
        return [origin.strip() for origin in self.allowed_origins.split(",")]

    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()
