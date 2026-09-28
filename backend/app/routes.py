from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select
from .database import get_session
from .hub import hub
from .models import DataPoint, DataPointCreate, DataPointUpdate
from .notifications import safe_dispatch_alarm

router = APIRouter(prefix="/api")


@router.get("/points", response_model=list[DataPoint])
def list_points(session: Session = Depends(get_session)):
    return session.exec(select(DataPoint).order_by(DataPoint.id)).all()


@router.post("/points", response_model=DataPoint, status_code=201)
async def create_point(payload: DataPointCreate, session: Session = Depends(get_session)):
    point = DataPoint.model_validate(payload)
    session.add(point)
    session.commit()
    session.refresh(point)
    await hub.publish({"type": "point.created", "point": point.model_dump()})
    return point


@router.patch("/points/{point_id}", response_model=DataPoint)
@router.put("/points/{point_id}", response_model=DataPoint)
async def update_point(point_id: int, payload: DataPointUpdate, session: Session = Depends(get_session)):
    point = session.get(DataPoint, point_id)
    if point is None:
        raise HTTPException(status_code=404, detail="Point not found")
    was_active = point.state
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(point, key, value)
    session.add(point)
    session.commit()
    session.refresh(point)
    await hub.publish({"type": "point.updated", "point": point.model_dump()})
    if point.state and not was_active:
        import asyncio
        asyncio.create_task(safe_dispatch_alarm(point.address, str(point.id)))
    return point


@router.delete("/points/{point_id}", status_code=204)
async def delete_point(point_id: int, session: Session = Depends(get_session)):
    point = session.get(DataPoint, point_id)
    if point is None:
        raise HTTPException(status_code=404, detail="Point not found")
    session.delete(point)
    session.commit()
    await hub.publish({"type": "point.deleted", "id": point_id})
