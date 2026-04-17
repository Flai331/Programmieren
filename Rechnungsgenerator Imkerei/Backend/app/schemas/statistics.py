"""Statistics schemas for API responses."""
from pydantic import BaseModel
from typing import List, Dict
from datetime import datetime


class InvoiceStatistics(BaseModel):
    """Schema for invoice statistics."""

    total_invoices: int
    total_revenue: float
    total_outstanding: float
    paid_invoices: int
    overdue_invoices: int
    draft_invoices: int
    average_invoice_value: float
    average_payment_days: float

    # Monthly breakdown
    monthly_revenue: List[Dict[str, float]]  # [{"month": "2024-01", "revenue": 1500.0}, ...]


class CustomerStatistics(BaseModel):
    """Schema for customer statistics."""

    customer_id: int
    customer_name: str
    total_invoices: int
    total_revenue: float
    outstanding_amount: float
    average_payment_days: float
    last_invoice_date: datetime | None
