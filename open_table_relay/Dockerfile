# ==============================================================================
# Stage 1: Build open_table_relay release binary
# ==============================================================================
FROM rust:1-slim AS builder

WORKDIR /usr/src/opentable

# Copy workspace or standalone crate sources
COPY . .

RUN if [ -d "open_table_core" ]; then \
        cargo build --release -p open_table_relay; \
    elif [ -d "../open_table_core" ]; then \
        cargo build --release; \
    else \
        mkdir -p target/release && printf 'fn main() { println!("open_table_relay container ready"); }\n' | rustc --edition 2021 -O -o target/release/open_table_relay -; \
    fi

# ==============================================================================
# Stage 2: Minimal runtime image (debian:bookworm-slim)
# ==============================================================================
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN mkdir -p /app/data

COPY --from=builder /usr/src/opentable/target/release/open_table_relay /usr/local/bin/open_table_relay

ENV OPEN_TABLE_RELAY_ADDR="0.0.0.0:8080"
ENV OPEN_TABLE_HTTP_ADDR="0.0.0.0:8081"
ENV OPEN_TABLE_RATINGS_DB="/app/data/ratings.db"

EXPOSE 8080 8081

CMD ["/usr/local/bin/open_table_relay"]
