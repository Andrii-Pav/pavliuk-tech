from datetime import datetime
from decimal import Decimal
from typing import Annotated, Optional

from pydantic import BaseModel, ConfigDict, Field, PlainSerializer, model_validator

from app.models import MovementReason

Money = Annotated[Decimal, Field(gt=0, max_digits=10, decimal_places=2)]
MoneyOut = Annotated[Decimal, PlainSerializer(float, return_type=float, when_used="json")]


class CategoryIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)


class CategoryOut(CategoryIn):
    model_config = ConfigDict(from_attributes=True)

    id: int


class ProductIn(BaseModel):
    sku: str = Field(min_length=1, max_length=50)
    name: str = Field(min_length=1, max_length=200)
    brand: str = Field(min_length=1, max_length=100)
    price: Money
    category_id: int


class ProductUpdate(BaseModel):
    sku: Optional[str] = Field(default=None, min_length=1, max_length=50)
    name: Optional[str] = Field(default=None, min_length=1, max_length=200)
    brand: Optional[str] = Field(default=None, min_length=1, max_length=100)
    price: Optional[Money] = None
    category_id: Optional[int] = None


class ProductOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sku: str
    name: str
    brand: str
    price: MoneyOut
    quantity: int
    category_id: int
    created_at: datetime
    updated_at: datetime


class MovementIn(BaseModel):
    change: int
    reason: MovementReason

    @model_validator(mode="after")
    def check_sign(self):
        if self.change == 0:
            raise ValueError("change must not be zero")
        if self.reason == MovementReason.receipt and self.change < 0:
            raise ValueError("receipt must have a positive change")
        if self.reason == MovementReason.sale and self.change > 0:
            raise ValueError("sale must have a negative change")
        return self


class MovementOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product_id: int
    change: int
    reason: MovementReason
    created_at: datetime
