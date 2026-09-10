# PostgreSQL 18 + PostGIS 3.6.4 + pgvector 0.8.6

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
| `postgis` | 3.6.4 | Spatial/GIS queries |
| `postgis_topology` | 3.6.4 | Topology support |
| `postgis_tiger_geocoder` | 3.6.4 | Geocoding |
| `fuzzystrmatch` | 1.2 | Fuzzy string matching |
| `vector` | 0.8.6 | Vector similarity search (includes the CVE-2026-3172 fix from 0.8.2, plus HNSW/IVFFlat correctness fixes through 0.8.6) |

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
ENV POSTGIS_VERSION=3.6.4
ENV PGVECTOR_VERSION=0.8.6
ENV PG_MAJOR=18
```

The actual package versions come from the Debian/PGDG repos. Run `apt-cache
show postgresql-${PG_MAJOR}-postgis-3` to see the current candidate.

**To pin exact versions** (production), add an `/etc/apt/preferences` file:

```dockerfile
RUN echo 'Package: postgresql-18-pgvector\nPin: version 0.8.6-1.pgdg13+1\nPin-Priority: 1001' \
    > /etc/apt/preferences.d/pin-pgvector
```

### Upgrading extensions in an existing database

Rebuilding the image installs new extension **binaries**, but a database created
by an earlier build still has the **old versions registered in its catalog**.
`docker-compose.yml` persists data in the `postgres_data` volume, so
`docker compose up -d --build` on its own will not upgrade them — and `init.sql`
will not either, since it runs only when the data directory is first
initialized. Check what the database actually has:

```sql
SELECT extname, extversion FROM pg_extension ORDER BY extname;
```

If those lag the versions in the table above, upgrade them in place once the
container is running the new image:

```sql
-- PostGIS: upgrades postgis together with whichever companion extensions are
-- installed (topology, tiger_geocoder, raster, sfcgal), in the right order.
-- Prefer this over a bare `ALTER EXTENSION postgis UPDATE`, which upgrades
-- only postgis itself and leaves the companions on the old version.
SELECT postgis_extensions_upgrade();

-- pgvector
ALTER EXTENSION vector UPDATE;
```

Run this in **every database** that has the extensions: `pg_extension` is
per-database, so upgrading `mydb` does nothing for any other database.

Neither step needs a `REINDEX` — existing data and indexes are preserved, and
the fixes apply to subsequent operations. The exception is an index an affected
version may already have damaged: for an HNSW index built with parallel workers
under pgvector 0.6.0–0.8.1 (CVE-2026-3172), or vacuumed under a version before
0.8.3, `REINDEX INDEX CONCURRENTLY <name>;` is the only way to be certain it is
sound. The sample `idx_exemplo_embedding` in `init.sql` is IVFFLAT, not HNSW,
and is not affected.

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
