-- Additive application tables documented by the admin module.
-- This migration is safe to run after 001_initial_schema.sql.

CREATE TABLE IF NOT EXISTS statistics (
  id BIGSERIAL PRIMARY KEY,
  metric_key VARCHAR(100) NOT NULL,
  metric_value NUMERIC NOT NULL DEFAULT 0,
  dimensions JSONB NOT NULL DEFAULT '{}'::jsonb,
  period_start TIMESTAMPTZ,
  period_end TIMESTAMPTZ,
  calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT statistics_period_order CHECK (
    period_start IS NULL OR period_end IS NULL OR period_end >= period_start
  ),
  CONSTRAINT statistics_metric_period_unique UNIQUE (
    metric_key,
    period_start,
    period_end
  )
);

CREATE INDEX IF NOT EXISTS idx_statistics_metric_calculated
  ON statistics(metric_key, calculated_at DESC);

CREATE TABLE IF NOT EXISTS admin_actions (
  id BIGSERIAL PRIMARY KEY,
  admin_user_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  action VARCHAR(100) NOT NULL,
  target_type VARCHAR(50),
  target_id INT,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  ip_address VARCHAR(45),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_actions_admin_created
  ON admin_actions(admin_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_actions_target
  ON admin_actions(target_type, target_id, created_at DESC);
