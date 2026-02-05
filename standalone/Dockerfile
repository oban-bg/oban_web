# Build

ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.2
ARG ALPINE_VERSION=3.22.3

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION} AS builder

ARG OBAN_LICENSE_KEY

RUN apk add --no-cache build-base git

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

RUN if [ -n "$OBAN_LICENSE_KEY" ]; then \
      mix hex.repo add oban https://repo.oban.pro \
        --fetch-public-key "SHA256:4/OSKi0NRF91QVVXlGAhb/BIMLnK8NHcx/EWs+aIWPc" \
        --auth-key "$OBAN_LICENSE_KEY"; \
    fi

ENV MIX_ENV=prod

COPY mix.exs ./
RUN mix deps.get --only prod

COPY config/config.exs config/
RUN mix deps.compile

COPY lib lib
RUN mix compile

COPY config/runtime.exs config/

RUN mix release oban_dash

# Runtime

ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION} AS runtime

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/oban_dash ./

RUN adduser -D -h /app oban && chown -R oban:oban /app
USER oban

ENV PORT=4000
EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q --spider http://localhost:${PORT}/health || exit 1

ENTRYPOINT ["/app/bin/oban_dash"]
CMD ["start"]
