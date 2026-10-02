-- La glycemie est desormais stockee en mmol/L et non plus en g/L.
-- Saisie en nombres entiers (5) au lieu de 0.9 : plus besoin de virgule
-- sur le clavier, et la valeur reste lisible par la patiente et le medecin.
--
-- Conversion : 1 mmol/L = 0,180182 g/L, donc g/L -> mmol/L en multipliant
-- par 5,5508 (masse molaire du glucose = 180,15588 g/mol).
--
-- Attention : migration a appliquer UNE SEULE FOIS. Les lignes inserees
-- apres cette date sont deja en mmol/L.
UPDATE telemetry
SET blood_glucose = ROUND((blood_glucose * 5.5508)::numeric, 2)
WHERE blood_glucose IS NOT NULL;