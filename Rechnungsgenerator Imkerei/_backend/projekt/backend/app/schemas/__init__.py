"""Pydantic schemas for API validation."""
from .customer import CustomerCreate, CustomerUpdate, CustomerResponse
from .invoice import (
    InvoiceCreate,
    InvoiceUpdate,
    InvoiceResponse,
    InvoiceItemCreate,
    InvoiceItemResponse,
)
from .article import ArticleCreate, ArticleUpdate, ArticleResponse
from .template import TemplateCreate, TemplateUpdate, TemplateResponse
from .statistics import InvoiceStatistics, CustomerStatistics

__all__ = [
    "CustomerCreate",
    "CustomerUpdate",
    "CustomerResponse",
    "InvoiceCreate",
    "InvoiceUpdate",
    "InvoiceResponse",
    "InvoiceItemCreate",
    "InvoiceItemResponse",
    "ArticleCreate",
    "ArticleUpdate",
    "ArticleResponse",
    "TemplateCreate",
    "TemplateUpdate",
    "TemplateResponse",
    "InvoiceStatistics",
    "CustomerStatistics",
]
