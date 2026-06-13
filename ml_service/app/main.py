from __future__ import annotations

from fastapi import FastAPI
from pydantic import BaseModel, Field
import numpy as np
from sentence_transformers import SentenceTransformer
import os

# Use a fast, standard, lightweight model
model_name = os.environ.get("EMBEDDING_MODEL", "all-MiniLM-L6-v2")
model = SentenceTransformer(model_name)


app = FastAPI(
    title="AI Recruiter Machine Learning Service",
    version="0.1.0",
    description="Intelligent profile analysis, semantic culture-fit scoring, and high-dimensional vector embeddings.",
)


@app.get("/health")
def health():
    return {"ok": True}


class CultureFitRequest(BaseModel):
    company_values: str = Field(..., min_length=3)
    interview_notes: str = Field(..., min_length=3)


class CultureFitResponse(BaseModel):
    score: float
    rationale: str


def get_embedding(text: str) -> np.ndarray:
    # Get high-quality sentence embeddings from the transformer model
    emb = model.encode(text)
    return emb


@app.post("/culture-fit/score", response_model=CultureFitResponse)
def culture_fit_score(req: CultureFitRequest):
    # Compute embeddings for company_values and interview_notes using the model's logic
    vec_values = get_embedding(req.company_values)
    vec_notes = get_embedding(req.interview_notes)
    
    # Cosine similarity
    dot = np.dot(vec_values, vec_notes)
    norm_val = np.linalg.norm(vec_values)
    norm_not = np.linalg.norm(vec_notes)
    similarity = float(dot / (norm_val * norm_not + 1e-8))
    
    # Scale similarity from [-1, 1] space into a human-friendly [0.35, 0.95] alignment score range
    score = float(np.clip(0.65 + similarity * 0.3, 0.0, 1.0))
    
    # Generate dynamic, context-aware analysis rationale based on alignment score
    if score >= 0.82:
        alignment = "Excellent"
        bullets = (
            "• Strongly displays behaviors and examples that match your core ideals.\n"
            "• Highly recommended team fit; responses show direct alignment with company goals."
        )
    elif score >= 0.68:
        alignment = "Strong"
        bullets = (
            "• Shows good alignment with key organizational objectives.\n"
            "• Moderate alignment on working styles; candidate is adaptive and fits well."
        )
    elif score >= 0.52:
        alignment = "Moderate"
        bullets = (
            "• Partially aligns with target values, but some divergence in working styles was observed.\n"
            "• May require active alignment training/coaching during onboarding."
        )
    else:
        alignment = "Low"
        bullets = (
            "• Significant misalignment with core cultural pillars.\n"
            "• Responses reflect values or habits that do not fit the team's working environment."
        )
        
    rationale = (
        f"AI Culture Fit Analysis: Found {alignment.lower()} alignment (score: {int(score * 100)}%) "
        f"between candidate interview responses and target organizational values.\n\n"
        f"Key Assessment Highlights:\n{bullets}\n\n"
        f"Feedback comparison based on values: '{req.company_values}'."
    )
    
    return CultureFitResponse(score=score, rationale=rationale)


class EmbeddingRequest(BaseModel):
    texts: list[str] = Field(..., min_length=1)


class EmbeddingResponse(BaseModel):
    dim: int
    vectors: list[list[float]]


@app.post("/embeddings", response_model=EmbeddingResponse)
def embeddings(req: EmbeddingRequest):
    vectors = [get_embedding(t).astype(float).tolist() for t in req.texts]
    dim = len(vectors[0]) if vectors else 384
    return EmbeddingResponse(dim=dim, vectors=vectors)
