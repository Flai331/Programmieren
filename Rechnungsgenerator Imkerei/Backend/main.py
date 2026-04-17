"""Main FastAPI application."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

from app.config import settings
from app.database import engine, Base
from app.api import customers, invoices, articles, templates, statistics, auth, email, backup

# Create database tables
Base.metadata.create_all(bind=engine)

# Create FastAPI app
app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="API für Rechnungsgenerator Imkerei",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create directories for file storage
os.makedirs(settings.upload_dir, exist_ok=True)
os.makedirs(settings.pdf_dir, exist_ok=True)
os.makedirs(settings.logo_dir, exist_ok=True)

# Mount static files
app.mount("/pdfs", StaticFiles(directory=settings.pdf_dir), name="pdfs")
app.mount("/logos", StaticFiles(directory=settings.logo_dir), name="logos")

# Include routers
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(customers.router, prefix="/api/customers", tags=["Customers"])
app.include_router(invoices.router, prefix="/api/invoices", tags=["Invoices"])
app.include_router(articles.router, prefix="/api/articles", tags=["Articles"])
app.include_router(templates.router, prefix="/api/templates", tags=["Templates"])
app.include_router(statistics.router, prefix="/api/statistics", tags=["Statistics"])
app.include_router(email.router, prefix="/api/email", tags=["Email"])
app.include_router(backup.router, prefix="/api/backup", tags=["Backup"])


@app.get("/")
def root():
    """Root endpoint."""
    return {
        "message": "Rechnungsgenerator Imkerei API",
        "version": settings.app_version,
        "docs": "/docs",
    }


@app.get("/health")
def health_check():
    """Health check endpoint."""
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.debug,
    )
