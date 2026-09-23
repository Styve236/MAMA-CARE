-- IA alerts : stockage structuré de l'analyse Gemini transmise au médecin.
ALTER TABLE alerts ADD COLUMN IF NOT EXISTS details JSONB;

CREATE INDEX IF NOT EXISTS idx_alerts_doctor_unread
  ON alerts(doctor_id, is_read, created_at DESC);