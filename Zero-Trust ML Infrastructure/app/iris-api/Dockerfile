FROM python:3.12-slim

RUN useradd --uid 10001 --create-home appuser
WORKDIR /app
COPY app.py /app/app.py

USER 10001:10001
ENV PORT=8080
ENV PYTHONDONTWRITEBYTECODE=1
EXPOSE 8080

CMD ["python", "/app/app.py"]
