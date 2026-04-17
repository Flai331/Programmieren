"""Article API endpoints."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from ..database import get_db
from ..models import Article
from ..schemas.article import ArticleCreate, ArticleUpdate, ArticleResponse

router = APIRouter()


@router.get("/", response_model=List[ArticleResponse])
def get_articles(
    skip: int = 0,
    limit: int = 100,
    category: str = None,
    search: str = None,
    active_only: bool = True,
    db: Session = Depends(get_db),
):
    """Get list of articles."""
    query = db.query(Article)

    if active_only:
        query = query.filter(Article.is_active == 1)

    if category:
        query = query.filter(Article.category == category)

    if search:
        search_filter = f"%{search}%"
        query = query.filter(
            (Article.name.ilike(search_filter))
            | (Article.description.ilike(search_filter))
            | (Article.article_number.ilike(search_filter))
        )

    articles = query.offset(skip).limit(limit).all()
    return articles


@router.get("/{article_id}", response_model=ArticleResponse)
def get_article(article_id: int, db: Session = Depends(get_db)):
    """Get article by ID."""
    article = db.query(Article).filter(Article.id == article_id).first()

    if not article:
        raise HTTPException(status_code=404, detail="Article not found")

    return article


@router.post("/", response_model=ArticleResponse, status_code=201)
def create_article(article: ArticleCreate, db: Session = Depends(get_db)):
    """Create new article."""
    db_article = Article(**article.model_dump())
    db.add(db_article)
    db.commit()
    db.refresh(db_article)
    return db_article


@router.put("/{article_id}", response_model=ArticleResponse)
def update_article(
    article_id: int,
    article: ArticleUpdate,
    db: Session = Depends(get_db),
):
    """Update article."""
    db_article = db.query(Article).filter(Article.id == article_id).first()

    if not db_article:
        raise HTTPException(status_code=404, detail="Article not found")

    update_data = article.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_article, key, value)

    db.commit()
    db.refresh(db_article)
    return db_article


@router.delete("/{article_id}", status_code=204)
def delete_article(article_id: int, db: Session = Depends(get_db)):
    """Delete article."""
    db_article = db.query(Article).filter(Article.id == article_id).first()

    if not db_article:
        raise HTTPException(status_code=404, detail="Article not found")

    db.delete(db_article)
    db.commit()
    return None
