"""Invoice template database model."""
from sqlalchemy import Column, Integer, String, DateTime, Text, LargeBinary
from sqlalchemy.sql import func
from ..database import Base


class InvoiceTemplate(Base):
    """Invoice template model for storing PDF templates and sender info."""

    __tablename__ = "invoice_templates"

    id = Column(Integer, primary_key=True, index=True)

    # Template Identification
    name = Column(String(255), nullable=False, index=True)
    description = Column(Text)

    # Sender Information
    sender_name = Column(String(255))
    sender_company = Column(String(255))
    sender_email = Column(String(255))
    sender_phone = Column(String(50))
    sender_street = Column(String(255))
    sender_postal_code = Column(String(20))
    sender_city = Column(String(100))
    sender_country = Column(String(100), default="Deutschland")

    # Business Information
    tax_id = Column(String(50))  # Steuernummer
    vat_id = Column(String(50))  # USt-IdNr.
    bank_name = Column(String(255))
    iban = Column(String(50))
    bic = Column(String(20))

    # PDF Template File
    pdf_template_path = Column(String(500))  # Path to uploaded PDF template
    logo_path = Column(String(500))  # Path to logo file

    # Template Settings (JSON or individual columns)
    # Positions for text placement on PDF
    invoice_number_x = Column(Integer, default=420)
    invoice_number_y = Column(Integer, default=150)

    invoice_date_x = Column(Integer, default=420)
    invoice_date_y = Column(Integer, default=170)

    customer_address_x = Column(Integer, default=50)
    customer_address_y = Column(Integer, default=220)

    items_start_x = Column(Integer, default=50)
    items_start_y = Column(Integer, default=350)
    items_line_height = Column(Integer, default=20)

    # Status
    is_default = Column(Integer, default=0)  # 1 = default template
    is_active = Column(Integer, default=1)  # 1 = aktiv, 0 = inaktiv

    # Metadata
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    def __repr__(self):
        return f"<InvoiceTemplate(id={self.id}, name='{self.name}')>"

    @property
    def full_address(self):
        """Get formatted sender address."""
        parts = [
            self.sender_name,
            self.sender_company,
            self.sender_street,
            f"{self.sender_postal_code} {self.sender_city}" if self.sender_postal_code and self.sender_city else None,
            self.sender_country if self.sender_country != "Deutschland" else None
        ]
        return "\n".join([p for p in parts if p])
