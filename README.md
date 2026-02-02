# ScalableProjectGiorgiaPirelli - Earthquake Co-occurrence Analysis

## Struttura del progetto

* `src/main/scala/EarthquakeCooccurrenceAnalysis.scala` - parte principale
* `src/main/scala/PairCounter.scala` - logica per il calcolo delle co-occorrenze tra coppie di locazioni
* `benchmarking_earthquake.ps1` - script PowerShell per creare cluster Dataproc, eseguire il job Spark e registrare i risultati

## Parametri di configurazione

Modificare le variabili nello script `benchmarking_earthquake.ps1` secondo il progetto e il bucket:

```powershell
$PROJECT        = "<YOUR_PROJECT_ID>"                    # ID del progetto 
$REGION         = "europe-west1"                         # regione
$ZONE           = "europe-west1-b"                       # zona 
$BUCKET         = "<YOUR_BUCKET_NAME>"                   # nome del bucket 
$JAR            = "gs://$BUCKET/jars/earthquake-app.jar" # nome dato al file .jar
$INPUT          = "gs://$BUCKET/dataset-earthquakes-full.csv" # dataset
$OUTPUT_BASE    = "gs://$BUCKET/output"                  # output
$MACHINE_TYPE   = "n2-standard-4"                        # tipo di macchina (n1-standard-2 o n2-standard-4)
$WORKERS_LIST   = @(2, 3, 4)                             # numero di worker da testare
$PARTITION_COUNTS = @(4, 8, 12, 16, 24)                  # configurazioni partizioni da testare
$CSV_FILE = "earthquake_scalability_results.csv"         # output
```

## Caricamento su bucket

### Compilare il progetto

```bash
sbt clean
sbt package
```

Il JAR generato si trova in: `target/scala-2.12/earthquake-app.jar`

# Caricare il JAR compilato
gsutil cp target/scala-2.12/earthquake-app.jar `
  gs://YOUR_BUCKET_NAME/jars/

# Esempio con il JAR utilizzato nel progetto:
gsutil cp target/scala-2.12/speriamo_2.12-0.1.0-SNAPSHOT.jar `
  gs://YOUR_BUCKET_NAME/jars/earthquake-app.jar

# Caricare il dataset
gsutil cp data/dataset-earthquakes-full.csv `
  gs://YOUR_BUCKET_NAME/
## Esecuzione script

Eseguire lo script di benchmark:

```powershell
.\benchmarking_earthquake.ps1
```

## Output risultati

I risultati vengono salvati nel file: `earthquake_scalability_results.csv`

```
Workers,Partitions,PartitionsPerWorker,StartTime,EndTime,DurationSeconds,Status,OutputPath
2,8,4,2026-02-01 15:40:12,2026-02-01 15:55:24,911.99,SUCCESS,gs://YOUR_BUCKET_NAME/output/w2_p8
3,16,5,2026-02-01 16:27:45,2026-02-01 16:35:15,450.10,SUCCESS,gs://YOUR_BUCKET_NAME/output/w3_p16
```
