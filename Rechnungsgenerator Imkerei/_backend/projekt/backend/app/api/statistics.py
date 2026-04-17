"""Statistics API endpoints."""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional

from ..database import get_db
from ..schemas.statistics import InvoiceStatistics, CustomerStatistics
from ..services.statistics_service import StatisticsService

router = APIRouter()


@router.get("/invoices", response_model=InvoiceStatistics)
def get_invoice_statistics(
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    db: Session = Depends(get_db),
):
    """Get invoice statistics."""
    # Default to last 12 months if no dates provided
    if not start_date:
        start_date = datetime.now() - timedelta(days=365)
    if not end_date:
        end_date = datetime.now()

    stats = StatisticsService.get_invoice_statistics(db, start_date, end_date)
    return stats


@router.get("/customers/{customer_id}", response_model=CustomerStatistics)
def get_customer_statistics(
    customer_id: int,
    db: Session = Depends(get_db),
):
    """Get statistics for specific customer."""
    stats = StatisticsService.get_customer_statistics(db, customer_id)

    if not stats:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Customer not found")

    return stats


@router.get("/top-customers")
def get_top_customers(
    limit: int = Query(10, le=50),
    db: Session = Depends(get_db),
):
    """Get top customers by revenue."""
    customers = StatisticsService.get_top_customers(db, limit)
    return customers
