"""Statistics service for invoice analytics."""
from sqlalchemy.orm import Session
from sqlalchemy import func, extract
from datetime import datetime, timedelta
from typing import List, Dict
from ..models import Invoice, Customer
from ..models.invoice import InvoiceStatus


class StatisticsService:
    """Service for invoice statistics and analytics."""

    @staticmethod
    def get_invoice_statistics(db: Session, start_date: datetime = None, end_date: datetime = None) -> Dict:
        """
        Get overall invoice statistics.

        Args:
            db: Database session
            start_date: Optional start date filter
            end_date: Optional end date filter

        Returns:
            Dictionary with statistics
        """
        # Build base query
        query = db.query(Invoice)

        if start_date:
            query = query.filter(Invoice.invoice_date >= start_date)
        if end_date:
            query = query.filter(Invoice.invoice_date <= end_date)

        invoices = query.all()

        # Calculate statistics
        total_invoices = len(invoices)
        total_revenue = sum(inv.total for inv in invoices if inv.status == InvoiceStatus.PAID)
        total_outstanding = sum(
            inv.total for inv in invoices if inv.status in [InvoiceStatus.SENT, InvoiceStatus.OVERDUE]
        )

        paid_invoices = sum(1 for inv in invoices if inv.status == InvoiceStatus.PAID)
        overdue_invoices = sum(1 for inv in invoices if inv.status == InvoiceStatus.OVERDUE)
        draft_invoices = sum(1 for inv in invoices if inv.status == InvoiceStatus.DRAFT)

        average_invoice_value = total_revenue / paid_invoices if paid_invoices > 0 else 0

        # Calculate average payment days
        payment_days = []
        for inv in invoices:
            if inv.status == InvoiceStatus.PAID and inv.paid_date and inv.invoice_date:
                days = (inv.paid_date - inv.invoice_date).days
                payment_days.append(days)

        average_payment_days = sum(payment_days) / len(payment_days) if payment_days else 0

        # Monthly revenue breakdown
        monthly_revenue = StatisticsService._get_monthly_revenue(db, start_date, end_date)

        return {
            "total_invoices": total_invoices,
            "total_revenue": round(total_revenue, 2),
            "total_outstanding": round(total_outstanding, 2),
            "paid_invoices": paid_invoices,
            "overdue_invoices": overdue_invoices,
            "draft_invoices": draft_invoices,
            "average_invoice_value": round(average_invoice_value, 2),
            "average_payment_days": round(average_payment_days, 1),
            "monthly_revenue": monthly_revenue,
        }

    @staticmethod
    def _get_monthly_revenue(db: Session, start_date: datetime = None, end_date: datetime = None) -> List[Dict]:
        """Get revenue grouped by month."""
        query = (
            db.query(
                extract("year", Invoice.invoice_date).label("year"),
                extract("month", Invoice.invoice_date).label("month"),
                func.sum(Invoice.total).label("revenue"),
            )
            .filter(Invoice.status == InvoiceStatus.PAID)
        )

        if start_date:
            query = query.filter(Invoice.invoice_date >= start_date)
        if end_date:
            query = query.filter(Invoice.invoice_date <= end_date)

        results = query.group_by("year", "month").order_by("year", "month").all()

        return [
            {
                "month": f"{int(r.year)}-{int(r.month):02d}",
                "revenue": round(float(r.revenue), 2),
            }
            for r in results
        ]

    @staticmethod
    def get_customer_statistics(db: Session, customer_id: int) -> Dict:
        """
        Get statistics for a specific customer.

        Args:
            db: Database session
            customer_id: Customer ID

        Returns:
            Dictionary with customer statistics
        """
        customer = db.query(Customer).filter(Customer.id == customer_id).first()

        if not customer:
            return None

        invoices = db.query(Invoice).filter(Invoice.customer_id == customer_id).all()

        total_invoices = len(invoices)
        total_revenue = sum(inv.total for inv in invoices if inv.status == InvoiceStatus.PAID)
        outstanding_amount = sum(
            inv.total for inv in invoices if inv.status in [InvoiceStatus.SENT, InvoiceStatus.OVERDUE]
        )

        # Calculate average payment days
        payment_days = []
        for inv in invoices:
            if inv.status == InvoiceStatus.PAID and inv.paid_date and inv.invoice_date:
                days = (inv.paid_date - inv.invoice_date).days
                payment_days.append(days)

        average_payment_days = sum(payment_days) / len(payment_days) if payment_days else 0

        # Last invoice date
        last_invoice = (
            db.query(Invoice)
            .filter(Invoice.customer_id == customer_id)
            .order_by(Invoice.invoice_date.desc())
            .first()
        )

        return {
            "customer_id": customer_id,
            "customer_name": customer.name,
            "total_invoices": total_invoices,
            "total_revenue": round(total_revenue, 2),
            "outstanding_amount": round(outstanding_amount, 2),
            "average_payment_days": round(average_payment_days, 1),
            "last_invoice_date": last_invoice.invoice_date if last_invoice else None,
        }

    @staticmethod
    def get_top_customers(db: Session, limit: int = 10) -> List[Dict]:
        """
        Get top customers by revenue.

        Args:
            db: Database session
            limit: Number of customers to return

        Returns:
            List of customer statistics
        """
        results = (
            db.query(
                Customer.id,
                Customer.name,
                func.count(Invoice.id).label("invoice_count"),
                func.sum(Invoice.total).label("total_revenue"),
            )
            .join(Invoice)
            .filter(Invoice.status == InvoiceStatus.PAID)
            .group_by(Customer.id, Customer.name)
            .order_by(func.sum(Invoice.total).desc())
            .limit(limit)
            .all()
        )

        return [
            {
                "customer_id": r.id,
                "customer_name": r.name,
                "invoice_count": r.invoice_count,
                "total_revenue": round(float(r.total_revenue), 2),
            }
            for r in results
        ]
