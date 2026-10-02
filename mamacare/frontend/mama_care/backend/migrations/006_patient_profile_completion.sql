-- Poids avant la grossesse (distinct du poids mesure dans telemetry)
ALTER TABLE patients
  ADD COLUMN IF NOT EXISTS pre_pregnancy_weight DECIMAL(5,2);

-- Contrainte de coerence, 20 a 300 kg
ALTER TABLE patients
  DROP CONSTRAINT IF EXISTS patients_pre_pregnancy_weight_check;

ALTER TABLE patients
  ADD CONSTRAINT patients_pre_pregnancy_weight_check
  CHECK (pre_pregnancy_weight IS NULL OR (pre_pregnancy_weight >= 20 AND pre_pregnancy_weight <= 300));