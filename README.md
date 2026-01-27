# ScalableProjectGiorgiaPirelli
Struttura del progetto

1. EarthquakeCooccurrenceAnalysis.scala: Punto di ingresso dell'applicazione, gestisce il parsing CSV, l'arrotondamento delle coordinate e l'estrazione della data.
2. PairCounter.scala: Logica MapReduce principale per il calcolo e l'aggregazione della co-occorrenza di coppie.
3. benchmarking_earthquake.ps1: Script PowerShell per automatizzare la creazione del cluster GCP, la sottomissione dei job e la raccolta delle metriche di performance.
4. build.sbt: Configurazione di build per il progetto Scala.
5. report/: Contiene la relazione tecnica dettagliata.
2. Build Locale
Compilare il progetto e generare il file JAR:
sbt clean
sbt package
Il JAR compilato si trova in: target/scala-2.12/speriamo_2.12-0.1.0-SNAPSHOT.jar

3. Deployment nel Cloud
Configurare GCP e caricare gli asset del progetto su Google Cloud Storage:
powershell# Impostare il progetto GCP attivo
gcloud config set project scalableproject-482714

# Creare la struttura del bucket di storage, se non è presente
$BUCKET = "terremoti-bucket-giorgiapirelli"
gsutil mb -l europe-west1 gs://$BUCKET/
gsutil mb gs://$BUCKET/jars/
gsutil mb gs://$BUCKET/dataset/
gsutil mb gs://$BUCKET/output/

# Caricare il JAR compilato
gsutil cp target\scala-2.12\speriamo_2.12-0.1.0-SNAPSHOT.jar `
  gs://terremoti-bucket-giorgiapirelli/jars/earthquake-app.jar

# Caricare il dataset dei terremoti
gsutil cp .\data\earthquakes-complete.csv `
  gs://terremoti-bucket-giorgiapirelli/dataset/
4. Esecuzione dei Benchmark
Lo script benchmarking_earthquake.ps1 automatizza il testing su diverse configurazioni di cluster. Modificare le variabili dello script secondo le proprie esigenze e quindi eseguire:
powershell.\benchmarking_earthquake.ps1
Lo script eseguirà automaticamente:

Creazione di cluster Dataproc con 2 e 3 worker nodes, per probelmi legtai alla creazione con 4 worker nodes.
Sottomissione di job Spark con partizioni ottimizzate (12, 24, 36)
Misurazione del tempo di esecuzione per ogni configurazione
Raccolta delle metriche in un file CSV: earthquake_scalability_results_FIXED.csv
Calcolo della scalabilità (speedup, efficienza parallela)
Eliminazione automatica dei cluster al termine
