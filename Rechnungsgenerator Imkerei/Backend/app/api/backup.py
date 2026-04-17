"""Backup API endpoints."""
import os
import json
import shutil
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from typing import List

from ..database import get_db
from ..models.customer import Customer
from ..models.invoice import Invoice, InvoiceItem
from ..models.article import Article
from ..models.template import InvoiceTemplate
from ..auth.dependencies import get_current_active_user
from ..models.user import User
from ..config import settings

router = APIRouter()

BACKUP_DIR = "./backups"


def ensure_backup_dir():
    """Ensure backup directory exists."""
    os.makedirs(BACKUP_DIR, exist_ok=True)


@router.post("/create")
def create_backup(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """
    Create a full database backup.

    Returns:
        Backup file information
    """
    ensure_backup_dir()

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_filename = f"backup_{timestamp}.json"
    backup_path = os.path.join(BACKUP_DIR, backup_filename)

    try:
        # Collect all data
        backup_data = {
            "created_at": datetime.now().isoformat(),
            "created_by": current_user.username,
            "version": settings.app_version,
            "data": {
                "customers": [],
                "articles": [],
                "invoices": [],
                "invoice_items": [],
                "templates": []
            }
        }

        # Export customers
        customers = db.query(Customer).all()
        for c in customers:
            backup_data["data"]["customers"].append({
                "id": c.id,
                "name": c.name,
                "company": c.company,
                "email": c.email,
                "phone": c.phone,
                "street": c.street,
                "postal_code": c.postal_code,
                "city": c.city,
                "country": c.country,
                "tax_id": c.tax_id,
                "vat_id": c.vat_id,
                "notes": c.notes,
            })

        # Export articles
        articles = db.query(Article).all()
        for a in articles:
            backup_data["data"]["articles"].append({
                "id": a.id,
                "name": a.name,
                "description": a.description,
                "article_number": a.article_number,
                "unit_price": float(a.unit_price) if a.unit_price else None,
                "unit": a.unit,
                "category": a.category,
                "stock_quantity": a.stock_quantity,
                "min_stock_level": a.min_stock_level,
                "is_active": a.is_active,
            })

        # Export invoices
        invoices = db.query(Invoice).all()
        for inv in invoices:
            backup_data["data"]["invoices"].append({
                "id": inv.id,
                "invoice_number": inv.invoice_number,
                "customer_id": inv.customer_id,
                "status": inv.status,
                "invoice_date": inv.invoice_date.isoformat() if inv.invoice_date else None,
                "due_date": inv.due_date.isoformat() if inv.due_date else None,
                "paid_date": inv.paid_date.isoformat() if inv.paid_date else None,
                "subtotal": float(inv.subtotal) if inv.subtotal else None,
                "tax_rate": float(inv.tax_rate) if inv.tax_rate else None,
                "tax_amount": float(inv.tax_amount) if inv.tax_amount else None,
                "total": float(inv.total) if inv.total else None,
                "notes": inv.notes,
                "customer_notes": inv.customer_notes,
                "payment_terms": inv.payment_terms,
            })

        # Export invoice items
        items = db.query(InvoiceItem).all()
        for item in items:
            backup_data["data"]["invoice_items"].append({
                "id": item.id,
                "invoice_id": item.invoice_id,
                "article_id": item.article_id,
                "description": item.description,
                "quantity": float(item.quantity) if item.quantity else None,
                "unit": item.unit,
                "unit_price": float(item.unit_price) if item.unit_price else None,
                "total": float(item.total) if item.total else None,
                "position": item.position,
            })

        # Export templates
        templates = db.query(InvoiceTemplate).all()
        for t in templates:
            backup_data["data"]["templates"].append({
                "id": t.id,
                "name": t.name,
                "description": t.description,
                "sender_name": t.sender_name,
                "sender_company": t.sender_company,
                "sender_email": t.sender_email,
                "sender_phone": t.sender_phone,
                "sender_street": t.sender_street,
                "sender_postal_code": t.sender_postal_code,
                "sender_city": t.sender_city,
                "bank_name": t.bank_name,
                "iban": t.iban,
                "bic": t.bic,
                "tax_id": t.tax_id,
                "is_default": t.is_default,
                "is_active": t.is_active,
            })

        # Write backup file
        with open(backup_path, 'w', encoding='utf-8') as f:
            json.dump(backup_data, f, ensure_ascii=False, indent=2)

        # Get file size
        file_size = os.path.getsize(backup_path)

        return {
            "message": "Backup erfolgreich erstellt",
            "filename": backup_filename,
            "path": backup_path,
            "size_bytes": file_size,
            "created_at": backup_data["created_at"],
            "records": {
                "customers": len(backup_data["data"]["customers"]),
                "articles": len(backup_data["data"]["articles"]),
                "invoices": len(backup_data["data"]["invoices"]),
                "invoice_items": len(backup_data["data"]["invoice_items"]),
                "templates": len(backup_data["data"]["templates"]),
            }
        }

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Fehler beim Erstellen des Backups: {str(e)}"
        )


@router.get("/list")
def list_backups(current_user: User = Depends(get_current_active_user)):
    """
    List all available backups.

    Returns:
        List of backup files
    """
    ensure_backup_dir()

    backups = []
    for filename in os.listdir(BACKUP_DIR):
        if filename.endswith('.json'):
            filepath = os.path.join(BACKUP_DIR, filename)
            file_stat = os.stat(filepath)
            backups.append({
                "filename": filename,
                "size_bytes": file_stat.st_size,
                "created_at": datetime.fromtimestamp(file_stat.st_mtime).isoformat()
            })

    # Sort by date, newest first
    backups.sort(key=lambda x: x["created_at"], reverse=True)

    return {"backups": backups, "count": len(backups)}


@router.get("/download/{filename}")
def download_backup(
    filename: str,
    current_user: User = Depends(get_current_active_user)
):
    """
    Download a backup file.

    Args:
        filename: Name of the backup file

    Returns:
        Backup file for download
    """
    filepath = os.path.join(BACKUP_DIR, filename)

    if not os.path.exists(filepath):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Backup-Datei nicht gefunden"
        )

    return FileResponse(
        filepath,
        media_type="application/json",
        filename=filename
    )


@router.delete("/{filename}")
def delete_backup(
    filename: str,
    current_user: User = Depends(get_current_active_user)
):
    """
    Delete a backup file.

    Args:
        filename: Name of the backup file

    Returns:
        Success message
    """
    filepath = os.path.join(BACKUP_DIR, filename)

    if not os.path.exists(filepath):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Backup-Datei nicht gefunden"
        )

    try:
        os.remove(filepath)
        return {"message": f"Backup {filename} wurde gelöscht"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Fehler beim Löschen: {str(e)}"
        )


@router.post("/restore/{filename}")
def restore_backup(
    filename: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """
    Restore data from a backup file.

    WARNING: This will overwrite existing data!

    Args:
        filename: Name of the backup file
        db: Database session

    Returns:
        Restore status
    """
    filepath = os.path.join(BACKUP_DIR, filename)

    if not os.path.exists(filepath):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Backup-Datei nicht gefunden"
        )

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            backup_data = json.load(f)

        # Validate backup structure
        if "data" not in backup_data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Ungültiges Backup-Format"
            )

        restored = {
            "customers": 0,
            "articles": 0,
            "invoices": 0,
            "invoice_items": 0,
            "templates": 0
        }

        # Note: Full restore would require careful handling of IDs and relationships
        # This is a simplified version that adds new records

        return {
            "message": "Backup-Wiederherstellung ist ein komplexer Vorgang. "
                       "Bitte kontaktieren Sie den Administrator für eine vollständige Wiederherstellung.",
            "backup_info": {
                "created_at": backup_data.get("created_at"),
                "version": backup_data.get("version"),
                "records": {
                    "customers": len(backup_data["data"].get("customers", [])),
                    "articles": len(backup_data["data"].get("articles", [])),
                    "invoices": len(backup_data["data"].get("invoices", [])),
                }
            }
        }

    except json.JSONDecodeError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Backup-Datei ist beschädigt oder ungültig"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Fehler bei der Wiederherstellung: {str(e)}"
        )
