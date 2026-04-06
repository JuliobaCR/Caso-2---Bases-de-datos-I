FROM python:3.12-slim

WORKDIR /app

COPY integracion/python/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY integracion/python/etl_unificacion.py /app/etl_unificacion.py

CMD ["python", "/app/etl_unificacion.py"]
