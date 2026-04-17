"""Invoice database models."""
from sqlalchemy import Column, Integer, String, DateTime, Float, ForeignKey, Text, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime, timedelta
import enum
from ..database import Base


class InvoiceStatus(str, enum.Enum):
    """Invoice status enumeration."""
    DRAFT = "draft"
    SENT = "sent"
    PAID = "paid"
    OVERDUE = "overdue"
    CANCELLED = "cancelled"


class Invoice(Base):
    """Invoice model for storing invoice information."""

    __tablename__ = "invoices"

    id = Column(Integer, primary_key=True, index=True)

    # Invoice Identification
    invoice_number = Column(String(50), unique=True, nullable=False, index=True)
    status = Column(Enum(InvoiceStatus), default=InvoiceStatus.DRAFT, index=True)

    # Customer Reference
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=False)

    # Dates
    invoice_date = Column(DateTime(timezone=True), default=func.now())
    due_date = Column(DateTime(timezone=True))
    paid_date = Column(DateTime(timezone=True))

    # Financial Information
    subtotal = Column(Float, default=0.0)  # Netto
    tax_rate = Column(Float, default=19.0)  # MwSt. %
    tax_amount = Column(Float, default=0.0)  # MwSt. Betrag
    total = Column(Float, default=0.0)  # Brutto

    # Template & Design
    template_id = Column(Integer, ForeignKey("invoice_templates.id"))

    # Additional Information
    notes = Column(Text)  # Notizen für interne Verwendung
    customer_notes = Column(Text)  # Notizen die auf der Rechnung erscheinen
    payment_terms = Column(Integer, default=14)  # Zahlungsziel in Tagen

    # Metadata
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    customer = relationship("Customer", back_populates="invoices")
    items = relationship("InvoiceItem", back_populates="invoice", cascade="all, delete-orphan")
    template = relationship("InvoiceTemplate")

    def __repr__(self):
        return f"<Invoice(id={self.id}, number='{self.invoice_number}', status='{self.status}')>"

    def calculate_totals(self):
        """Calculate invoice totals from items."""
        self.subtotal = sum(item.total for item in self.items)
        self.tax_amount = self.subtotal * (self.tax_rate / 100)
        self.total = self.subtotal + self.tax_amount

    def set_due_date(self):
        """Set due date based on payment terms."""
        if self.invoice_date and self.payment_terms:
            self.due_date = self.invoice_date + timedelta(days=self.payment_terms)

    @property
    def is_overdue(self):
        """Check if invoice is overdue."""
        if self.status == InvoiceStatus.PAID:
            return False
        if self.due_date:
            return datetime.now() > self.due_date
        return False


class InvoiceItem(Base):
    """Invoice item/position model."""

    __tablename__ = "invoice_items"

    id = Column(Integer, primary_key=True, index=True)

    # Invoice Reference
    invoice_id = Column(Integer, ForeignKey("invoices.id"), nullable=False)

    # Item Information
    description = Column(String(500), nullable=False)
    quantity = Column(Float, nullable=False, default=1.0)
    unit = Column(String(50), default="Stück")  # Stück, kg, Liter, etc.
    unit_price = Column(Float, nullable=False)
    total = Column(Float, nullable=False)

    # Optional Article Reference
    article_id = Column(Integer, ForeignKey("articles.id"))

    # Position on invoice
    position = Column(Integer, default=0)

    # Relationships
    invoice = relationship("Invoice", back_populates="items")
    article = relationship("Article")

    def __repr__(self):
        return f"<InvoiceItem(id={self.id}, description='{self.description}', total={self.total})>"

    def calculate_total(self):
        """Calculate item total."""
        self.total = self.quantity * self.unit_price
