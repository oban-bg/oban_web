# Standalone

A standalone Docker image is available for situations where you want an Oban dashboard without
mounting Oban.Web within your application. This is useful for:

- Running the dashboard separately from your main application
- Monitoring jobs created by [Oban for Python][oban-py] applications

[oban-py]: https://github.com/oban-bg/oban-py

> #### Interaction with Oban {: .info}
> 
> The standalone dashboard operates in a monitoring-only capacity:
> 
> - It connects to an existing database with Oban tables already present
> - It does not run migrations or create tables
> - It does not process jobs (`plugins: false`, `queues: false`)
> - Queue scaling operations affect the connected application's queues
>
> When deploying to a production environment you should add authentication and potentially set
> read only mode.

## Quick Start

Pull and run the image with your database connection:

```bash
docker run -d \
  -e DATABASE_URL="postgres://user:pass@host:5432/myapp_prod" \
  -p 4000:4000 \
  ghcr.io/oban-bg/oban-dash
```

Then visit `http://localhost:4000/oban`.

When connecting to a database on your host machine, use `host.docker.internal` instead of
`localhost`:

```diff
 docker run -d \
-  -e DATABASE_URL="postgres://user:pass@host:5432/myapp_prod" \
+  -e DATABASE_URL="postgres://user:pass@host.docker.internal:5432/myapp_dev" \
   -p 4000:4000 \
   ghcr.io/oban-bg/oban-dash
```

The image is built for both `amd64` and `arm64` architectures. If you need to specify a platform
explicitly, use the `--platform` flag:

```diff
+docker run --platform linux/arm64 -d \
   -e DATABASE_URL="postgres://user:pass@host.docker.internal:5432/myapp_dev" \
   -p 4000:4000 \
   ghcr.io/oban-bg/oban-dash
```

## Configuration

All configuration is done through environment variables:

| Variable          | Required   | Default   | Description                     |
| ----------------- | ---------- | --------- | ------------------------------- |
| `DATABASE_URL`    | Yes        | —         | PostgreSQL connection URL       |
| `POOL_SIZE`       | No         | `5`       | Database connection pool size   |
| `PORT`            | No         | `4000`    | HTTP port                       |
| `OBAN_PREFIX`     | No         | `public`  | Oban table schema prefix        |
| `OBAN_READ_ONLY`  | No         | `false`   | Disable job actions when `true` |
| `BASIC_AUTH_USER` | No         | —         | Basic auth username             |
| `BASIC_AUTH_PASS` | No         | —         | Basic auth password             |
| `LOG_LEVEL`       | No         | `info`    | Log level                       |

## Authentication & Authorization

A simple authentication mechanism is built in and enabled with environment variables. Enable HTTP
Basic Authentication by setting both `BASIC_AUTH_USER` and `BASIC_AUTH_PASS`:

```diff
 docker run -d \
   -e DATABASE_URL="postgres://user:pass@host.docker.internal:5432/myapp" \
+  -e BASIC_AUTH_USER="admin" \
+  -e BASIC_AUTH_PASS="secret" \
   -p 4000:4000 \
   ghcr.io/oban-bg/oban-dash
```

It's also possible to disable job actions such as cancel, retry, delete, etc. by enabling
read-only mode:

```diff
 docker run -d \
   -e DATABASE_URL="postgres://user:pass@host.docker.internal:5432/myapp" \
+  -e OBAN_READ_ONLY="true" \
   -p 4000:4000 \
   ghcr.io/oban-bg/oban-dash
```

## Oban Pro

To use [Oban Pro][pro] features like the Smart Engine, you'll need to build the image with your
license key. The published `ghcr.io/oban-bg/oban-dash` image only includes the open source
components.

Build with your Oban Pro license:

```bash
git clone https://github.com/oban-bg/oban_web.git
cd oban_web/standalone
docker build \
  --build-arg OBAN_LICENSE_KEY="your_license_key" \
  -t oban-dash-pro .
```

Then run your custom image:

```bash
docker run -d \
  -e DATABASE_URL="postgres://user:pass@host.docker.internal:5432/myapp" \
  -p 4000:4000 \
  oban-dash-pro
```

[pro]: https://oban.pro

## Health Checks

The container exposes a health check endpoint at `/health` that returns `{"status":"ok"}`.
Docker's built-in `HEALTHCHECK` is configured to monitor this endpoint automatically, making the
image suitable for orchestration systems like Kubernetes or Amazon ECS.
