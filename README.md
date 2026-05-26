# PostgreSQL 18 + PostGIS 3.6.3 + pgvector 0.8.2

Docker image based on the official `postgres:18` (Debian 13 Trixie) with PostGIS
and pgvector pre-installed via apt packages — no source compile overhead.

**Inspired by** [garapadev/postgres-postgis-pgvector](https://github.com/garapadev/postgres-postgis-pgvector)
(PG16-based). This image adapts the same pattern for PostgreSQL 18.

## Quick start

```bash
docker run -d \
  --name pg18 \
  -e POSTGRES_DB=mydb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  ghcr.io/iravench/postgres-18:latest
```

Or with docker-compose (included):

```bash
docker-compose up -d
```

## What you get

| Extension | Version | Notes |
|---|---|---|
| `postgis` | 3.6.3 | Spatial/GIS queries |
| `postgis_topology` | 3.6.3 | Topology support |
| `postgis_tiger_geocoder` | 3.6.3 | Geocoding |
| `fuzzystrmatch` | 1.2 | Fuzzy string matching |
| `vector` | 0.8.2 | Vector similarity search (fixes CVE-2026-3172) |

On first start, `init.sql` creates a sample table `exemplo_dados` with spatial
(POINT) and vector (VECTOR(3)) columns, inserts sample data, builds GiST +
IVFFLAT indexes, and runs demo queries. Container logs show everything working.

## Build locally

```bash
docker build -t pg18-pgvector-postgis .
```

No compile step — extensions install in ~30s via apt.

## Maintenance — updating versions

This image uses **apt packages** rather than source compilation. To update
extension versions:

```dockerfile
# Bump these ENVs to document the new versions (informational only)
ENV POSTGIS_VERSION=3.6.3
ENV PGVECTOR_VERSION=0.8.2
ENV PG_MAJOR=18
```

The actual package versions come from the Debian/PGDG repos. Run `apt-cache
show postgresql-${PG_MAJOR}-postgis-3` to see the current candidate.

**To pin exact versions** (production), add an `/etc/apt/preferences` file:

```dockerfile
RUN echo 'Package: postgresql-18-pgvector\nPin: version 0.8.2-1.pgdg13+1\nPin-Priority: 1001' \
    > /etc/apt/preferences.d/pin-pgvector
```

### Upgrading a running container

```sql
ALTER EXTENSION postgis UPDATE;
ALTER EXTENSION vector UPDATE;
```

## Files

```
├── Dockerfile            # Build recipe
├── docker-compose.yml    # Convenience compose file
└── sql/
    └── init.sql          # Runs at first container start
```

## Credits

Pattern and init.sql sample data adapted from
[garapadev/postgres-postgis-pgvector](https://github.com/garapadev/postgres-postgis-pgvector).
