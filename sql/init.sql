-- init.sql — runs automatically on first container start via
-- /docker-entrypoint-initdb.d/. Creates PostGIS and pgvector extensions,
-- then creates a sample table with spatial + vector data to verify both work.

-- === 1. Extension creation ===
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
CREATE EXTENSION IF NOT EXISTS vector;

-- === 2. Verify installed versions ===
SELECT version();

SELECT extname, extversion
FROM pg_extension
WHERE extname IN ('postgis', 'vector', 'postgis_topology', 'fuzzystrmatch', 'postgis_tiger_geocoder')
ORDER BY extname;

SELECT PostGIS_Full_Version();

-- === 3. Sample data table for quick testing ===
CREATE TABLE IF NOT EXISTS exemplo_dados (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100),
    localizacao GEOMETRY(POINT, 4326),
    embedding VECTOR(3),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO exemplo_dados (nome, localizacao, embedding) VALUES
    ('São Paulo',       ST_SetSRID(ST_MakePoint(-46.6333, -23.5505), 4326), '[0.1, 0.2, 0.3]'::vector),
    ('Rio de Janeiro',  ST_SetSRID(ST_MakePoint(-43.1729, -22.9068), 4326), '[0.4, 0.5, 0.6]'::vector),
    ('Brasília',        ST_SetSRID(ST_MakePoint(-47.8826, -15.7942), 4326), '[0.7, 0.8, 0.9]'::vector),
    ('Lisboa',          ST_SetSRID(ST_MakePoint( -9.1399,   38.7227), 4326), '[0.2, 0.3, 0.4]'::vector);

-- GiST index for spatial queries, IVFFLAT for vector similarity
CREATE INDEX IF NOT EXISTS idx_exemplo_localizacao ON exemplo_dados USING GIST (localizacao);
CREATE INDEX IF NOT EXISTS idx_exemplo_embedding  ON exemplo_dados USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- === 4. Quick demo queries (output logged at startup) ===
\echo '--- PostGIS: nearest city to São Paulo ---'
SELECT nome, ST_AsText(localizacao) AS coordenadas,
       ST_Distance(localizacao, ST_SetSRID(ST_MakePoint(-46.6333, -23.5505), 4326)) AS distancia_graus
FROM exemplo_dados
WHERE nome <> 'São Paulo'
ORDER BY distancia_graus
LIMIT 2;

\echo '--- pgvector: closest vectors to São Paulo (0.1,0.2,0.3) ---'
SELECT nome, embedding <=> '[0.1, 0.2, 0.3]'::vector AS cosine_distance
FROM exemplo_dados
WHERE nome <> 'São Paulo'
ORDER BY cosine_distance
LIMIT 2;

\echo ''
\echo '✅ PostgreSQL 18 + PostGIS 3.6.4 + pgvector 0.8.6 ready'
\echo '   Sample table exemplo_dados with spatial + vector data created'
\echo ''
