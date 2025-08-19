-- Initialize PostgreSQL for Query Optimizer API
-- This script runs when the database container starts for the first time

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Create database if it doesn't exist (handled by POSTGRES_DB env var)
-- This file is mainly for any additional setup needed
