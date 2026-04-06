FROM python:3.11-slim

WORKDIR /app

# Install dependencies first (cached layer)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Render injects PORT as an env variable (default 5000)
ENV PORT=5000

EXPOSE ${PORT}

# Run with gunicorn (4 workers, bind to Render's PORT)
CMD gunicorn --bind 0.0.0.0:${PORT} --workers 4 --timeout 120 app:app
