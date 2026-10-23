from pydantic import BaseModel


class SearchResultItem(BaseModel):
    studio_id: str
    studio_name: str
    set_id: str
    set_name: str
    avatar_url: str
    similarity_score: float


class SearchResponse(BaseModel):
    results: list[SearchResultItem]


class EncodeResponse(BaseModel):
    embedding: list[float]


class ReindexResponse(BaseModel):
    indexed_count: int


class HealthResponse(BaseModel):
    status: str
    indexed_sets: int
