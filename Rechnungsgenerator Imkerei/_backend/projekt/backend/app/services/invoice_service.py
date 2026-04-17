"""Invoice business logic service."""
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List, Optional
from ..models import Invoice, InvoiceItem, Customer, InvoiceTemplate
from ..models.invoice import InvoiceStatus
from ..schemas.invoice import InvoiceCreate, InvoiceUpdate
from ..config import settings


class InvoiceService:
    """Service for invoice-related business logic."""

    @staticmethod
    def generate_invoice_number(db: Session) -> str:
        """
        Generate next invoice number.

        Args:
            db: Database session

        Returns:
            Next invoice number (e.g., "RE-1001")
        """
        # Get latest invoice
        latest_invoice = (
            db.query(Invoice)
            .filter(Invoice.invoice_number.like(f"{settings.invoice_number_prefix}-%"))
            .order_by(Invoice.id.desc())
            .first()
        )

        if latest_invoice:
            # Extract number from latest invoice
            try:
                last_number = int(latest_invoice.invoice_number.split("-")[1])
                next_number = last_number + 1
            except (IndexError, ValueError):
                next_number = settings.invoice_number_start
        else:
            next_number = settings.invoice_number_start

        return f"{settings.invoice_number_prefix}-{next_number}"

    @staticmethod
    def create_invoice(db: Session, invoice_data: InvoiceCreate) -> Invoice:
        """
        Create a new invoice with items.

        Args:
            db: Database session
            invoice_data: Invoice creation data

        Returns:
            Created invoice
        """
        # Generate invoice number
        invoice_number = InvoiceService.generate_invoice_number(db)

        # Create invoice
        invoice = Invoice(
            invoice_number=invoice_number,
            customer_id=invoice_data.customer_id,
            invoice_date=invoice_data.invoice_date or datetime.now(),
            payment_terms=invoice_data.payment_terms,
            tax_rate=invoice_data.tax_rate,
            notes=invoice_data.notes,
            customer_notes=invoice_data.customer_notes,
            template_id=invoice_data.template_id,
            status=InvoiceStatus.DRAFT,
        )

        # Set due date
        invoice.set_due_date()

        # Add items
        for idx, item_data in enumerate(invoice_data.items):
            item = InvoiceItem(
                description=item_data.description,
                quantity=item_data.quantity,
                unit=item_data.unit,
                unit_price=item_data.unit_price,
                article_id=item_data.article_id,
                position=idx,
            )
            item.calculate_total()
            invoice.items.append(item)

        # Calculate totals
        invoice.calculate_totals()

        db.add(invoice)
        db.commit()
        db.refresh(invoice)

        return invoice

    @staticmethod
    def update_invoice(db: Session, invoice_id: int, invoice_data: InvoiceUpdate) -> Optional[Invoice]:
        """
        Update an existing invoice.

        Args:
            db: Database session
            invoice_id: Invoice ID
            invoice_data: Update data

        Returns:
            Updated invoice or None if not found
        """
        invoice = db.query(Invoice).filter(Invoice.id == invoice_id).first()

        if not invoice:
            return None

        # Update basic fields
        update_data = invoice_data.model_dump(exclude_unset=True, exclude={"items"})
        for key, value in update_data.items():
            setattr(invoice, key, value)

        # Update items if provided
        if invoice_data.items is not None:
            # Remove old items
            db.query(InvoiceItem).filter(InvoiceItem.invoice_id == invoice_id).delete()

            # Add new items
            for idx, item_data in enumerate(invoice_data.items):
                item = InvoiceItem(
                    invoice_id=invoice_id,
                    description=item_data.description,
                    quantity=item_data.quantity,
                    unit=item_data.unit,
                    unit_price=item_data.unit_price,
                    article_id=item_data.article_id,
                    position=idx,
                )
                item.calculate_total()
                db.add(item)

        # Recalculate totals
        db.refresh(invoice)
        invoice.calculate_totals()

        db.commit()
        db.refresh(invoice)

        return invoice

    @staticmethod
    def mark_as_sent(db: Session, invoice_id: int) -> Optional[Invoice]:
        """
        Mark invoice as sent.

        Args:
            db: Database session
            invoice_id: Invoice ID

        Returns:
            Updated invoice or None if not found
        """
        invoice = db.query(Invoice).filter(Invoice.id == invoice_id).first()

        if invoice:
            invoice.status = InvoiceStatus.SENT
            db.commit()
            db.refresh(invoice)

        return invoice

    @staticmethod
    def mark_as_paid(db: Session, invoice_id: int, paid_date: Optional[datetime] = None) -> Optional[Invoice]:
        """
        Mark invoice as paid.

        Args:
            db: Database session
            invoice_id: Invoice ID
            paid_date: Payment date (defaults to now)

        Returns:
            Updated invoice or None if not found
        """
        invoice = db.query(Invoice).filter(Invoice.id == invoice_id).first()

        if invoice:
            invoice.status = InvoiceStatus.PAID
            invoice.paid_date = paid_date or datetime.now()
            db.commit()
            db.refresh(invoice)

        return invoice

    @staticmethod
    def get_overdue_invoices(db: Session) -> List[Invoice]:
        """
        Get all overdue invoices.

        Args:
            db: Database session

        Returns:
            List of overdue invoices
        """
        return (
            db.query(Invoice)
            .filter(
                Invoice.status.in_([InvoiceStatus.SENT, InvoiceStatus.DRAFT]),
                Invoice.due_date < datetime.now(),
            )
            .all()
        )

    @staticmethod
    def update_overdue_status(db: Session):
        """
        Update status of overdue invoices.

        Args:
            db: Database session
        """
        overdue_invoices = InvoiceService.get_overdue_invoices(db)

        for invoice in overdue_invoices:
            invoice.status = InvoiceStatus.OVERDUE

        db.commit()
