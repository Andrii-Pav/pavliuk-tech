import os
from pathlib import Path
from typing import Optional

from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from app import models, schemas
from app.database import Base, engine, get_db

Base.metadata.create_all(bind=engine)

VERSION = os.getenv("APP_VERSION", "dev")
STATIC_DIR = Path(__file__).parent / "static"

app = FastAPI(title="Pavliuk-Tech Inventory")
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


@app.exception_handler(IntegrityError)
def integrity_error_handler(request, exc):
    return JSONResponse(
        status_code=409,
        content={"detail": "Conflict with existing data (duplicate value or related records)"},
    )


def get_or_404(db: Session, model, item_id: int):
    item = db.get(model, item_id)
    if item is None:
        raise HTTPException(status_code=404, detail=f"{model.__name__} not found")
    return item


@app.get("/", include_in_schema=False)
def index():
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/health")
def health():
    return {"status": "ok", "version": VERSION}


@app.get("/health/db")
def health_db(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
    except SQLAlchemyError:
        raise HTTPException(status_code=503, detail="Database unavailable")
    return {"status": "ok", "database": "up"}


@app.post("/categories", response_model=schemas.CategoryOut, status_code=201)
def create_category(data: schemas.CategoryIn, db: Session = Depends(get_db)):
    category = models.Category(**data.model_dump())
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


@app.get("/categories", response_model=list[schemas.CategoryOut])
def list_categories(db: Session = Depends(get_db)):
    return db.query(models.Category).order_by(models.Category.name).all()


@app.put("/categories/{category_id}", response_model=schemas.CategoryOut)
def update_category(
    category_id: int, data: schemas.CategoryIn, db: Session = Depends(get_db)
):
    category = get_or_404(db, models.Category, category_id)
    category.name = data.name
    db.commit()
    db.refresh(category)
    return category


@app.delete("/categories/{category_id}", status_code=204)
def delete_category(category_id: int, db: Session = Depends(get_db)):
    db.delete(get_or_404(db, models.Category, category_id))
    db.commit()


@app.post("/products", response_model=schemas.ProductOut, status_code=201)
def create_product(data: schemas.ProductIn, db: Session = Depends(get_db)):
    get_or_404(db, models.Category, data.category_id)
    product = models.Product(**data.model_dump())
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


@app.get("/products", response_model=list[schemas.ProductOut])
def list_products(
    category_id: Optional[int] = None,
    q: Optional[str] = None,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    query = db.query(models.Product)
    if category_id is not None:
        query = query.filter(models.Product.category_id == category_id)
    if q:
        query = query.filter(models.Product.name.ilike(f"%{q}%"))
    return query.order_by(models.Product.id).offset(offset).limit(limit).all()


@app.get("/products/{product_id}", response_model=schemas.ProductOut)
def get_product(product_id: int, db: Session = Depends(get_db)):
    return get_or_404(db, models.Product, product_id)


@app.put("/products/{product_id}", response_model=schemas.ProductOut)
def update_product(
    product_id: int, data: schemas.ProductUpdate, db: Session = Depends(get_db)
):
    product = get_or_404(db, models.Product, product_id)
    changes = data.model_dump(exclude_none=True)
    if "category_id" in changes:
        get_or_404(db, models.Category, changes["category_id"])
    for field, value in changes.items():
        setattr(product, field, value)
    db.commit()
    db.refresh(product)
    return product


@app.delete("/products/{product_id}", status_code=204)
def delete_product(product_id: int, db: Session = Depends(get_db)):
    db.delete(get_or_404(db, models.Product, product_id))
    db.commit()


@app.post(
    "/products/{product_id}/movements",
    response_model=schemas.MovementOut,
    status_code=201,
)
def add_movement(
    product_id: int, data: schemas.MovementIn, db: Session = Depends(get_db)
):
    product = (
        db.query(models.Product)
        .filter(models.Product.id == product_id)
        .with_for_update()
        .first()
    )
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    if product.quantity + data.change < 0:
        raise HTTPException(status_code=409, detail="Not enough stock")

    product.quantity += data.change
    movement = models.StockMovement(
        product_id=product.id, change=data.change, reason=data.reason.value
    )
    db.add(movement)
    db.commit()
    db.refresh(movement)
    return movement


@app.get("/products/{product_id}/movements", response_model=list[schemas.MovementOut])
def list_movements(product_id: int, db: Session = Depends(get_db)):
    get_or_404(db, models.Product, product_id)
    return (
        db.query(models.StockMovement)
        .filter(models.StockMovement.product_id == product_id)
        .order_by(models.StockMovement.id.desc())
        .all()
    )
