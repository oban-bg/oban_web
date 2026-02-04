# Build stage
ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.2
ARG ALPINE_VERSION=3.22.3

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION} AS builder

ARG OBAN_LICENSE
ARG OBAN_KEY_FINGERPRINT

RUN apk add --no-cache build-base git

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

RUN if [ -n "$OBAN_LICENSE" ]; then \
      mix hex.repo add oban https://getoban.pro/repo \
        --fetch-public-key "$OBAN_KEY_FINGERPRINT" \
        --auth-key "$OBAN_LICENSE"; \
    fi

ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs ./
RUN mix deps.get --only prod

# Copy compile-time config and compile dependencies
COPY config/config.exs config/
RUN mix deps.compile

# Copy application code and compile
COPY lib lib
RUN mix compile

# Copy runtime config (changes here won't trigger recompilation)
COPY config/runtime.exs config/

# Build release
RUN mix release oban_dashboard

# Runtime stage
ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION} AS runtime

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/oban_dashboard ./

RUN adduser -D -h /app oban && chown -R oban:oban /app
USER oban

ENV PORT=4000
EXPOSE 4000

ENTRYPOINT ["/app/bin/oban_dashboard"]
CMD ["start"]
