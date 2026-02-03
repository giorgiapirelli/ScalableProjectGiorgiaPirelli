# ScalableProjectGiorgiaPirelli - Earthquake Co-occurrence Analysis

## Struttura del progetto

* `src/main/scala/EarthquakeCooccurrenceAnalysis.scala` - parte principale
* `src/main/scala/PairCounter.scala` - logica per il calcolo delle co-occorrenze tra coppie di locazioni
* `setup_gcloud.ps1` - script PowerShell per la configurazione automatica di Google Cloud Storage
* `benchmarking_earthquake.ps1` - script PowerShell per creare cluster Dataproc, eseguire il job Spark e registrare i risultati

Lo script `setup_gcloud.ps1` automatizza la configurazione dell'infrastruttura su Google Cloud Platform. Esegue le seguenti operazioni:
  
### Configurazione setup_gcloud.ps1

Modificare le variabili all'inizio dello script:

```powershell
$PROJECT_ID = "YOUR_PROJECT_ID"                          # ID del progetto 
$BUCKET_NAME = "YOUR_BUCKET_NAME"                        # nome del bucket 
$REGION = "europe-west1"                                 # regione 
$SBT_JAR_PATH = "target\scala-2.12\speriamo_2.12-0.1.0-SNAPSHOT.jar"  # percorso JAR compilato da SBT (esempio utilizzato)
$JAR_NAME = "earthquake-app.jar"                         # nome JAR nel bucket
$DATASET_NAME = "dataset-earthquakes-full.csv"           # nome dataset nel bucket
```

### Esecuzione setup

Eseguire lo script di setup prima di avviare il benchmark:

```powershell
.\setup_gcloud.ps1
```

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

### Step 1: Si può anche compilare il progetto manualmente

```bash
sbt clean
sbt package
```

Il JAR generato si trova in: `target/scala-2.12/speriamo_2.12-0.1.0-SNAPSHOT.jar` (esempio nella mia cartella sorgente).

### Step 2: Eseguire setup automatico

```powershell
.\setup_gcloud.ps1
```

## Esecuzione Benchmark

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
Esempio file di output:
Il file `output_w3_p16_part-00000` contiene la lista completa delle date di co-occorrenza in formato YYYY-MM-DD, una per riga in ordine cronologico.
