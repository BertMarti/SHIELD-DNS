FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y dnsmasq unbound

COPY docker/requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ src/

EXPOSE 8000 53/udp 53/tcp

CMD ["python", "src/main.py"]
