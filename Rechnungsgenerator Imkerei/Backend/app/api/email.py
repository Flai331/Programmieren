"""Email API endpoints."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr
from typing import Optional

from ..database import get_db
from ..models.invoice import Invoice
from ..models.customer import Customer
from ..services.email_service import get_email_service
from ..services.pdf_generator import PDFGenerator
from ..auth.dependencies import get_current_active_user
from ..models.user import User

router = APIRouter()


class SendInvoiceEmailRequest(BaseModel):
    """Request model for sending invoice email."""
    invoice_id: int
    to_email: Optional[EmailStr] = None  # If not provided, use customer email
    custom_message: Optional[str] = None


class SendEmailRequest(BaseModel):
    """Request model for sending generic email."""
    to_email: EmailStr
    subject: str
    body: str
    attachment_path: Optional[str] = None


@router.post("/send-invoice")
def send_invoice_email(
    request: SendInvoiceEmailRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """
    Send an invoice via email.

    Args:
        request: Invoice email request data
        db: Database session
        current_user: Authenticated user

    Returns:
        Success message
    """
    # Get email service
    email_service = get_email_service()
    if not email_service:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="E-Mail-Service nicht konfiguriert. Bitte SMTP-Einstellungen in .env setzen."
        )

    # Get invoice
    invoice = db.query(Invoice).filter(Invoice.id == request.invoice_id).first()
    if not invoice:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Rechnung nicht gefunden"
        )

    # Get customer
    customer = db.query(Customer).filter(Customer.id == invoice.customer_id).first()
    if not customer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kunde nicht gefunden"
        )

    # Determine recipient email
    to_email = request.to_email or customer.email
    if not to_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Keine E-Mail-Adresse angegeben und Kunde hat keine E-Mail"
        )

    # Generate PDF if not exists
    pdf_generator = PDFGenerator()
    pdf_path = pdf_generator.generate_invoice_pdf(invoice, db)

    # Send email
    success = email_service.send_invoice(
        to_email=to_email,
        customer_name=customer.name or customer.company,
        invoice_number=invoice.invoice_number,
        pdf_path=pdf_path,
        custom_message=request.custom_message
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Fehler beim E-Mail-Versand"
        )

    # Mark invoice as sent
    invoice.status = "sent"
    db.commit()

    return {
        "message": f"Rechnung {invoice.invoice_number} wurde an {to_email} gesendet",
        "invoice_id": invoice.id,
        "recipient": to_email
    }


@router.get("/config-status")
def get_email_config_status(current_user: User = Depends(get_current_active_user)):
    """
    Check if email service is configured.

    Returns:
        Email configuration status
    """
    email_service = get_email_service()

    return {
        "configured": email_service is not None,
        "message": "E-Mail-Service ist konfiguriert" if email_service else "E-Mail-Service nicht konfiguriert"
    }
