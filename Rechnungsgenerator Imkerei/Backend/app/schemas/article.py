"""Article schemas for API validation."""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class ArticleBase(BaseModel):
    """Base article schema with common fields."""

    name: str
    description: Optional[str] = None
    article_number: Optional[str] = None
    unit_price: float
    unit: str = "Stück"
    category: Optional[str] = None
    stock_quantity: float = 0.0
    min_stock_level: float = 0.0
    is_active: int = 1


class ArticleCreate(ArticleBase):
    """Schema for creating a new article."""
    pass


class ArticleUpdate(BaseModel):
    """Schema for updating an article."""

    name: Optional[str] = None
    description: Optional[str] = None
    article_number: Optional[str] = None
    unit_price: Optional[float] = None
    unit: Optional[str] = None
    category: Optional[str] = None
    stock_quantity: Optional[float] = None
    min_stock_level: Optional[float] = None
    is_active: Optional[int] = None


class ArticleResponse(ArticleBase):
    """Schema for article response."""

    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None
    is_low_stock: bool

    class Config:
        from_attributes = True
