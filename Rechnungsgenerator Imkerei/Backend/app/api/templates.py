"""Template API endpoints."""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from typing import List
import os
import shutil

from ..database import get_db
from ..models import InvoiceTemplate
from ..schemas.template import TemplateCreate, TemplateUpdate, TemplateResponse
from ..config import settings

router = APIRouter()


@router.get("/", response_model=List[TemplateResponse])
def get_templates(
    active_only: bool = True,
    db: Session = Depends(get_db),
):
    """Get list of templates."""
    query = db.query(InvoiceTemplate)

    if active_only:
        query = query.filter(InvoiceTemplate.is_active == 1)

    templates = query.all()
    return templates


@router.get("/{template_id}", response_model=TemplateResponse)
def get_template(template_id: int, db: Session = Depends(get_db)):
    """Get template by ID."""
    template = db.query(InvoiceTemplate).filter(InvoiceTemplate.id == template_id).first()

    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    return template


@router.post("/", response_model=TemplateResponse, status_code=201)
def create_template(template: TemplateCreate, db: Session = Depends(get_db)):
    """Create new template."""
    # If this is set as default, unset other defaults
    if template.is_default:
        db.query(InvoiceTemplate).update({"is_default": 0})

    db_template = InvoiceTemplate(**template.model_dump())
    db.add(db_template)
    db.commit()
    db.refresh(db_template)
    return db_template


@router.post("/{template_id}/upload-pdf")
def upload_template_pdf(
    template_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    """Upload PDF template file."""
    template = db.query(InvoiceTemplate).filter(InvoiceTemplate.id == template_id).first()

    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    # Validate file type
    if not file.filename.endswith(".pdf"):
        raise HTTPException(status_code=400, detail="File must be a PDF")

    # Save file
    file_path = os.path.join(settings.upload_dir, f"template_{template_id}.pdf")

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # Update template
    template.pdf_template_path = file_path
    db.commit()

    return {"message": "Template PDF uploaded successfully", "path": file_path}


@router.post("/{template_id}/upload-logo")
def upload_logo(
    template_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    """Upload logo file."""
    template = db.query(InvoiceTemplate).filter(InvoiceTemplate.id == template_id).first()

    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    # Validate file type
    allowed_extensions = [".png", ".jpg", ".jpeg", ".svg"]
    if not any(file.filename.lower().endswith(ext) for ext in allowed_extensions):
        raise HTTPException(status_code=400, detail="File must be an image (PNG, JPG, or SVG)")

    # Save file
    file_extension = os.path.splitext(file.filename)[1]
    file_path = os.path.join(settings.logo_dir, f"logo_{template_id}{file_extension}")

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # Update template
    template.logo_path = file_path
    db.commit()

    return {"message": "Logo uploaded successfully", "path": file_path}


@router.put("/{template_id}", response_model=TemplateResponse)
def update_template(
    template_id: int,
    template: TemplateUpdate,
    db: Session = Depends(get_db),
):
    """Update template."""
    db_template = db.query(InvoiceTemplate).filter(InvoiceTemplate.id == template_id).first()

    if not db_template:
        raise HTTPException(status_code=404, detail="Template not found")

    # If this is set as default, unset other defaults
    if template.is_default == 1:
        db.query(InvoiceTemplate).filter(InvoiceTemplate.id != template_id).update({"is_default": 0})

    update_data = template.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_template, key, value)

    db.commit()
    db.refresh(db_template)
    return db_template


@router.delete("/{template_id}", status_code=204)
def delete_template(template_id: int, db: Session = Depends(get_db)):
    """Delete template."""
    db_template = db.query(InvoiceTemplate).filter(InvoiceTemplate.id == template_id).first()

    if not db_template:
        raise HTTPException(status_code=404, detail="Template not found")

    # Delete associated files
    if db_template.pdf_template_path and os.path.exists(db_template.pdf_template_path):
        os.remove(db_template.pdf_template_path)

    if db_template.logo_path and os.path.exists(db_template.logo_path):
        os.remove(db_template.logo_path)

    db.delete(db_template)
    db.commit()
    return None
