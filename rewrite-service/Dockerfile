# Stage 1 - install dependencies
FROM python:3.12-slim AS builder
ENV POETRY_VIRTUALENVS_CREATE=false
WORKDIR /app
COPY requirements.txt ./
RUN pip install --upgrade pip && pip install --prefix=/install -r requirements.txt

# Stage 2 - runtime image
FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1
WORKDIR /app
COPY --from=builder /install /usr/local
COPY app.py ./
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
