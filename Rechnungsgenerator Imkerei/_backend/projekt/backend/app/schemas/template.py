"""Template schemas for API validation."""
from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime


class TemplateBase(BaseModel):
    """Base template schema with common fields."""

    name: str
    description: Optional[str] = None
    sender_name: Optional[str] = None
    sender_company: Optional[str] = None
    sender_email: Optional[EmailStr] = None
    sender_phone: Optional[str] = None
    sender_street: Optional[str] = None
    sender_postal_code: Optional[str] = None
    sender_city: Optional[str] = None
    sender_country: str = "Deutschland"
    tax_id: Optional[str] = None
    vat_id: Optional[str] = None
    bank_name: Optional[str] = None
    iban: Optional[str] = None
    bic: Optional[str] = None
    is_default: int = 0
    is_active: int = 1


class TemplateCreate(TemplateBase):
    """Schema for creating a new template."""
    pass


class TemplateUpdate(BaseModel):
    """Schema for updating a template."""

    name: Optional[str] = None
    description: Optional[str] = None
    sender_name: Optional[str] = None
    sender_company: Optional[str] = None
    sender_email: Optional[EmailStr] = None
    sender_phone: Optional[str] = None
    sender_street: Optional[str] = None
    sender_postal_code: Optional[str] = None
    sender_city: Optional[str] = None
    sender_country: Optional[str] = None
    tax_id: Optional[str] = None
    vat_id: Optional[str] = None
    bank_name: Optional[str] = None
    iban: Optional[str] = None
    bic: Optional[str] = None
    pdf_template_path: Optional[str] = None
    logo_path: Optional[str] = None
    is_default: Optional[int] = None
    is_active: Optional[int] = None
    # Position fields
    invoice_number_x: Optional[int] = None
    invoice_number_y: Optional[int] = None
    invoice_date_x: Optional[int] = None
    invoice_date_y: Optional[int] = None
    customer_address_x: Optional[int] = None
    customer_address_y: Optional[int] = None
    items_start_x: Optional[int] = None
    items_start_y: Optional[int] = None
    items_line_height: Optional[int] = None


class TemplateResponse(TemplateBase):
    """Schema for template response."""

    id: int
    pdf_template_path: Optional[str] = None
    logo_path: Optional[str] = None
    invoice_number_x: int
    invoice_number_y: int
    invoice_date_x: int
    invoice_date_y: int
    customer_address_x: int
    customer_address_y: int
    items_start_x: int
    items_start_y: int
    items_line_height: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
