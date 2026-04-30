FROM python:3.11-slim

WORKDIR /app

# Install system dependencies required by LightGBM and CatBoost
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Install dependencies first (cached layer)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt apscheduler

# Copy application code
COPY . .

# Hugging Face Spaces expects port 7860
ENV PORT=7860

EXPOSE 7860

# Run with gunicorn (2 workers to reduce API pressure, longer timeout for startup)
CMD gunicorn --bind 0.0.0.0:7860 --workers 2 --timeout 300 app:app
