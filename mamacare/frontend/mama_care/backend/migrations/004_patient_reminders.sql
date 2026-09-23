-- Rappels personnalisés de la patiente (vitamines, rendez-vous, prise de sang...).
CREATE TABLE IF NOT EXISTS patient_reminders (
  id SERIAL PRIMARY KEY,
  patient_id INT NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  reminder_date TIMESTAMP NOT NULL,
  is_done BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_patient_reminders_patient_date
  ON patient_reminders(patient_id, reminder_date);