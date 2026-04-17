"""Invoice schemas for API validation."""
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from ..models.invoice import InvoiceStatus


class InvoiceItemBase(BaseModel):
    """Base invoice item schema."""

    description: str
    quantity: float
    unit: str = "Stück"
    unit_price: float
    article_id: Optional[int] = None
    position: int = 0


class InvoiceItemCreate(InvoiceItemBase):
    """Schema for creating an invoice item."""
    pass


class InvoiceItemResponse(InvoiceItemBase):
    """Schema for invoice item response."""

    id: int
    invoice_id: int
    total: float

    class Config:
        from_attributes = True


class InvoiceBase(BaseModel):
    """Base invoice schema with common fields."""

    customer_id: int
    invoice_date: Optional[datetime] = None
    payment_terms: int = 14
    tax_rate: float = 19.0
    notes: Optional[str] = None
    customer_notes: Optional[str] = None
    template_id: Optional[int] = None


class InvoiceCreate(InvoiceBase):
    """Schema for creating a new invoice."""

    items: List[InvoiceItemCreate]


class InvoiceUpdate(BaseModel):
    """Schema for updating an invoice."""

    customer_id: Optional[int] = None
    status: Optional[InvoiceStatus] = None
    invoice_date: Optional[datetime] = None
    due_date: Optional[datetime] = None
    paid_date: Optional[datetime] = None
    payment_terms: Optional[int] = None
    tax_rate: Optional[float] = None
    notes: Optional[str] = None
    customer_notes: Optional[str] = None
    template_id: Optional[int] = None
    items: Optional[List[InvoiceItemCreate]] = None


class InvoiceResponse(InvoiceBase):
    """Schema for invoice response."""

    id: int
    invoice_number: str
    status: InvoiceStatus
    due_date: Optional[datetime] = None
    paid_date: Optional[datetime] = None
    subtotal: float
    tax_amount: float
    total: float
    created_at: datetime
    updated_at: Optional[datetime] = None
    items: List[InvoiceItemResponse]
    is_overdue: bool

    class Config:
        from_attributes = True


class InvoiceListResponse(BaseModel):
    """Schema for invoice list item (without items)."""

    id: int
    invoice_number: str
    status: InvoiceStatus
    customer_id: int
    invoice_date: datetime
    due_date: Optional[datetime] = None
    total: float
    is_overdue: bool
    created_at: datetime

    class Config:
        from_attributes = True
