"""Invoice API endpoints."""
from fastapi import APIRouter, Depends, HTTPException, Response
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from typing import List
import os

from ..database import get_db
from ..models import Invoice, Customer, InvoiceTemplate
from ..models.invoice import InvoiceStatus
from ..schemas.invoice import InvoiceCreate, InvoiceUpdate, InvoiceResponse, InvoiceListResponse
from ..services.invoice_service import InvoiceService
from ..services.pdf_generator import PDFGenerator
from ..config import settings

router = APIRouter()


@router.get("/", response_model=List[InvoiceListResponse])
def get_invoices(
    skip: int = 0,
    limit: int = 100,
    status: InvoiceStatus = None,
    customer_id: int = None,
    db: Session = Depends(get_db),
):
    """Get list of invoices."""
    query = db.query(Invoice)

    if status:
        query = query.filter(Invoice.status == status)

    if customer_id:
        query = query.filter(Invoice.customer_id == customer_id)

    invoices = query.order_by(Invoice.invoice_date.desc()).offset(skip).limit(limit).all()
    return invoices


@router.get("/{invoice_id}", response_model=InvoiceResponse)
def get_invoice(invoice_id: int, db: Session = Depends(get_db)):
    """Get invoice by ID."""
    invoice = db.query(Invoice).filter(Invoice.id == invoice_id).first()

    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")

    return invoice


@router.post("/", response_model=InvoiceResponse, status_code=201)
def create_invoice(invoice: InvoiceCreate, db: Session = Depends(get_db)):
    """Create new invoice."""
    # Verify customer exists
    customer = db.query(Customer).filter(Customer.id == invoice.customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")

    # Create invoice using service
    db_invoice = InvoiceService.create_invoice(db, invoice)
    return db_invoice


@router.put("/{invoice_id}", response_model=InvoiceResponse)
def update_invoice(
    invoice_id: int,
    invoice: InvoiceUpdate,
    db: Session = Depends(get_db),
):
    """Update invoice."""
    db_invoice = InvoiceService.update_invoice(db, invoice_id, invoice)

    if not db_invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")

    return db_invoice


@router.post("/{invoice_id}/mark-sent", response_model=InvoiceResponse)
def mark_invoice_sent(invoice_id: int, db: Session = Depends(get_db)):
    """Mark invoice as sent."""
    db_invoice = InvoiceService.mark_as_sent(db, invoice_id)

    if not db_invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")

    return db_invoice


@router.post("/{invoice_id}/mark-paid", response_model=InvoiceResponse)
def mark_invoice_paid(invoice_id: int, db: Session = Depends(get_db)):
    """Mark invoice as paid."""
    db_invoice = InvoiceService.mark_as_paid(db, invoice_id)

    if not db_invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")

    return db_invoice


@router.get("/{invoice_id}/pdf")
def generate_invoice_pdf(invoice_id: int, db: Session = Depends(get_db)):
    """Generate and download invoice PDF."""
    invoice = db.query(Invoice).filter(Invoice.id == invoice_id).first()

    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")

    # Get customer and template
    customer = invoice.customer
    template = invoice.template if invoice.template else db.query(InvoiceTemplate).filter(InvoiceTemplate.is_default == 1).first()

    if not template:
        raise HTTPException(status_code=500, detail="No template found")

    # Prepare data for PDF generator
    invoice_data = {
        "invoice_number": invoice.invoice_number,
        "invoice_date": invoice.invoice_date,
        "due_date": invoice.due_date,
        "subtotal": invoice.subtotal,
        "tax_rate": invoice.tax_rate,
        "tax_amount": invoice.tax_amount,
        "total": invoice.total,
        "customer_notes": invoice.customer_notes,
        "items": invoice.items,
    }

    customer_data = {
        "name": customer.name,
        "company": customer.company,
        "street": customer.street,
        "postal_code": customer.postal_code,
        "city": customer.city,
    }

    items_data = [
        {
            "description": item.description,
            "quantity": item.quantity,
            "unit": item.unit,
            "unit_price": item.unit_price,
            "total": item.total,
        }
        for item in invoice.items
    ]

    template_data = {
        "sender_name": template.sender_name,
        "sender_company": template.sender_company,
        "sender_email": template.sender_email,
        "bank_name": template.bank_name,
        "iban": template.iban,
        "bic": template.bic,
        "tax_id": template.tax_id,
        "vat_id": template.vat_id,
        "invoice_number_x": template.invoice_number_x,
        "invoice_number_y": template.invoice_number_y,
        "invoice_date_x": template.invoice_date_x,
        "invoice_date_y": template.invoice_date_y,
        "customer_address_x": template.customer_address_x,
        "customer_address_y": template.customer_address_y,
        "items_start_x": template.items_start_x,
        "items_start_y": template.items_start_y,
        "items_line_height": template.items_line_height,
    }

    # Generate PDF
    output_path = os.path.join(settings.pdf_dir, f"invoice_{invoice.invoice_number}.pdf")

    pdf_generator = PDFGenerator(template.pdf_template_path if template.pdf_template_path else None)
    pdf_generator.generate_invoice_pdf(invoice_data, customer_data, items_data, template_data, output_path)

    # Return PDF file
    return FileResponse(
        output_path,
        media_type="application/pdf",
        filename=f"Rechnung_{invoice.invoice_number}.pdf",
    )


@router.delete("/{invoice_id}", status_code=204)
def delete_invoice(invoice_id: int, db: Session = Depends(get_db)):
    """Delete invoice."""
    db_invoice = db.query(Invoice).filter(Invoice.id == invoice_id).first()

    if not db_invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")

    db.delete(db_invoice)
    db.commit()
    return None
