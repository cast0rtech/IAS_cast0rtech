FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends asterisk && rm -rf /var/lib/apt/lists/*
COPY etc/asterisk/ /etc/asterisk/
EXPOSE 5060/udp 5038/tcp 10000-10100/udp
CMD ["asterisk", "-f", "-U", "asterisk", "-G", "asterisk"]
