"""Customer database model."""
from sqlalchemy import Column, Integer, String, DateTime, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class Customer(Base):
    """Customer model for storing client information."""

    __tablename__ = "customers"

    id = Column(Integer, primary_key=True, index=True)

    # Basic Information
    name = Column(String(255), nullable=False, index=True)
    company = Column(String(255))
    email = Column(String(255), index=True)
    phone = Column(String(50))

    # Address
    street = Column(String(255))
    postal_code = Column(String(20))
    city = Column(String(100))
    country = Column(String(100), default="Deutschland")

    # Additional Information
    tax_id = Column(String(50))  # Steuernummer
    vat_id = Column(String(50))  # USt-IdNr.
    notes = Column(Text)

    # Metadata
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    invoices = relationship("Invoice", back_populates="customer", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<Customer(id={self.id}, name='{self.name}')>"

    @property
    def full_address(self):
        """Get formatted full address."""
        parts = [
            self.street,
            f"{self.postal_code} {self.city}" if self.postal_code and self.city else None,
            self.country if self.country != "Deutschland" else None
        ]
        return "\n".join([p for p in parts if p])
