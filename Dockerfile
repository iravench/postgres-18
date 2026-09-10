# =============================================================================
# PostgreSQL 18 + PostGIS 3.6.4 + pgvector 0.8.6
#
# Base: postgres:18 (Debian 13 Trixie)
# Extensions installed via apt packages — no compile overhead.
#
# Security: pgvector 0.8.6 carries the CVE-2026-3172 fix (buffer overflow
# in parallel HNSW index builds, fixed in 0.8.2) plus later correctness
# fixes: possible HNSW index corruption during vacuum and a PG18-specific
# Hamming/Jaccard performance regression (0.8.3), HNSW vacuum errors and
# IVFFlat builds exceeding maintenance_work_mem (0.8.4), and IVFFlat scan
# memory in nested-loop joins (0.8.6 — init.sql builds an ivfflat index).
# PostGIS 3.6.4 fixes a Flatgeobuf schema vulnerability and a pg_upgrade
# failure on non-standard geography SRIDs. Both extensions track PGDG
# security patches automatically via apt, unlike pinned source builds.
#
# For local development. Production: pin apt package versions via
# version pinning in /etc/apt/preferences or use a tagged base image.
# =============================================================================

FROM postgres:18

LABEL maintainer="user (local build)"
LABEL description="PostgreSQL 18 with PostGIS 3.6.4 + pgvector 0.8.6 — apt-based"
LABEL version="1.0"

# Document the extension versions shipped by these apt packages.
# These are informational — the actual versions come from the repo.
ENV POSTGIS_VERSION=3.6.4
ENV PGVECTOR_VERSION=0.8.6
ENV PG_MAJOR=18

# Upgrade base system packages for latest security fixes, then install
# PostGIS and pgvector from the Debian Trixie/PGDG repos.
#
# Note: upgrading in-place breaks bitwise reproducibility (build today vs
# build in 3 months may differ). For local dev the security benefit outweighs
# this. Production: pin apt package versions or rely on fresh base pulls.
#
# postgresql-18-postgis-3  → PostGIS ${POSTGIS_VERSION}
# postgresql-18-pgvector   → pgvector ${PGVECTOR_VERSION} (PG18 native, post-CVE-2026-3172)
RUN apt-get update -qq && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends \
        postgresql-${PG_MAJOR}-postgis-3 \
        postgresql-${PG_MAJOR}-pgvector \
        postgresql-${PG_MAJOR}-postgis-3-scripts \
    && rm -rf /var/lib/apt/lists/*

# Copy the init script that creates extensions on first container start
COPY sql/init.sql /docker-entrypoint-initdb.d/

# Default env vars (can be overridden at runtime)
ENV POSTGRES_DB=mydb
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres

EXPOSE 5432

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB} || exit 1
