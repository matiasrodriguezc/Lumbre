-- Paso 63 (prueba de carga): /daily-sparks atiende 200 usuarios por llamada en ~2,5 s, pero con el cron cada 15 minutos
-- el batch salía a unos 800 usuarios por hora: 5.000 en la misma zona tardaban más de 6 horas en tener su chispa.
-- Cada minuto da unos 12.000 por hora. Una llamada sin usuarios pendientes tarda ~70 ms.
-- Si dos llamadas se solaparan, sparks_one_daily_idx y el unique de spark_jobs impiden la chispa doble.
select cron.alter_job(jobid, schedule := '* * * * *')
from cron.job
where jobname = 'chispas-diarias';
