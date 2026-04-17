"""Article/Product database model."""
from sqlalchemy import Column, Integer, String, Float, Text, DateTime
from sqlalchemy.sql import func
from ..database import Base


class Article(Base):
    """Article model for storing product catalog."""

    __tablename__ = "articles"

    id = Column(Integer, primary_key=True, index=True)

    # Article Information
    name = Column(String(255), nullable=False, index=True)
    description = Column(Text)
    article_number = Column(String(50), unique=True, index=True)

    # Pricing
    unit_price = Column(Float, nullable=False)
    unit = Column(String(50), default="Stück")  # Stück, kg, Liter, Glas, etc.

    # Categorization
    category = Column(String(100))  # z.B. "Honig", "Bienenwachs", "Propolis"

    # Stock (optional)
    stock_quantity = Column(Float, default=0.0)
    min_stock_level = Column(Float, default=0.0)

    # Metadata
    is_active = Column(Integer, default=1)  # 1 = aktiv, 0 = inaktiv
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    def __repr__(self):
        return f"<Article(id={self.id}, name='{self.name}', price={self.unit_price})>"

    @property
    def is_low_stock(self):
        """Check if article is low on stock."""
        return self.stock_quantity <= self.min_stock_level
