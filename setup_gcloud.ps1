# setup_gcloud.ps1 - Giorgia Pirelli
# Script di configurazione Google Cloud Storage
# Dataset già presente nel bucket
$PROJECT_ID = "scalableproject-482714"
$BUCKET_NAME = "terremoti-bucket-giorgiapirelli"
$REGION = "europe-west1"

# Percorsi JAR (sia dalla build che da sbt)
$SBT_JAR_PATH = "target\scala-2.12\speriamo_2.12-0.1.0-SNAPSHOT.jar"
$JAR_NAME = "earthquake-app.jar"
$DATASET_NAME = "dataset-earthquakes-full.csv"

# SETUP
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Google Cloud Storage Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Imposta progetto
Write-Host "Setting project to $PROJECT_ID..." -ForegroundColor Yellow
gcloud.cmd config set project $PROJECT_ID

# Crea bucket se non esiste
Write-Host "Checking bucket..." -ForegroundColor Yellow
gsutil.cmd ls -b gs://$BUCKET_NAME >$null 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Bucket already exists." -ForegroundColor Green
    $BUCKET_EXISTS = $true
} else {
    Write-Host "Creating bucket..." -ForegroundColor Yellow
    gsutil.cmd mb -p $PROJECT_ID -l $REGION gs://$BUCKET_NAME
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Bucket created successfully!" -ForegroundColor Green
        $BUCKET_EXISTS = $false
    } else {
        Write-Host "ERROR: Failed to create bucket" -ForegroundColor Red
        exit 1
    }
}

# Crea struttura cartelle solo se il bucket è nuovo
if (-not $BUCKET_EXISTS) {
    Write-Host "Creating bucket folders..." -ForegroundColor Yellow
    echo "placeholder" | gsutil.cmd cp - gs://$BUCKET_NAME/jars/.placeholder
    echo "placeholder" | gsutil.cmd cp - gs://$BUCKET_NAME/output/.placeholder
}

# VERIFICA E BUILD JAR
Write-Host ""

# Controlla se il JAR esiste già
if (Test-Path $SBT_JAR_PATH) {
    Write-Host "JAR already exists at $SBT_JAR_PATH" -ForegroundColor Green
    Write-Host "Skipping SBT build..." -ForegroundColor Yellow
} else {
    Write-Host "JAR not found at $SBT_JAR_PATH" -ForegroundColor Yellow
    Write-Host "Building JAR with SBT..." -ForegroundColor Yellow
    Write-Host ""

    # Pulisci build precedenti
    Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
    sbt clean
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: SBT clean failed" -ForegroundColor Red
        exit 1
    }

    # Package con sbt
    Write-Host "Packaging with SBT..." -ForegroundColor Yellow
    sbt package
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: SBT package failed" -ForegroundColor Red
        exit 1
    }

    Write-Host "SBT build completed successfully!" -ForegroundColor Green
    Write-Host ""
}

# UPLOAD JAR
Write-Host ""
Write-Host "Checking JAR in GCS..." -ForegroundColor Yellow
gsutil.cmd ls gs://$BUCKET_NAME/jars/$JAR_NAME >$null 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "JAR already exists on GCS!" -ForegroundColor Green
    Write-Host "Location: gs://$BUCKET_NAME/jars/$JAR_NAME" -ForegroundColor Cyan
    Write-Host "Skipping upload..." -ForegroundColor Yellow
} else {
    Write-Host "JAR not found on GCS, uploading..." -ForegroundColor Yellow
    if (Test-Path $SBT_JAR_PATH) {
        gsutil.cmd cp $SBT_JAR_PATH gs://$BUCKET_NAME/jars/$JAR_NAME
        if ($LASTEXITCODE -eq 0) {
            Write-Host "JAR uploaded successfully!" -ForegroundColor Green
            Write-Host "Location: gs://$BUCKET_NAME/jars/$JAR_NAME" -ForegroundColor Cyan
        } else {
            Write-Host "ERROR: Failed to upload JAR to GCS" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "ERROR: JAR not found at $SBT_JAR_PATH" -ForegroundColor Red
        Write-Host "Build failed or JAR path is incorrect." -ForegroundColor Yellow
        exit 1
    }
}

# VERIFICA DATASET
Write-Host ""
Write-Host "Checking dataset in bucket..." -ForegroundColor Yellow
if (gsutil.cmd ls gs://$BUCKET_NAME/$DATASET_NAME 2>$null) {
    Write-Host "Dataset found: $DATASET_NAME" -ForegroundColor Green
} else {
    Write-Host "ERROR: Dataset NOT found in bucket!" -ForegroundColor Red
    exit 1
}

# SUMMARY
Write-Host ""
Write-Host "Showing bucket contents:" -ForegroundColor Cyan
gsutil.cmd ls -r gs://$BUCKET_NAME/

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " SETUP COMPLETED SUCCESSFULLY" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "JAR: gs://$BUCKET_NAME/jars/$JAR_NAME" -ForegroundColor Cyan
Write-Host "Dataset: gs://$BUCKET_NAME/$DATASET_NAME" -ForegroundColor Cyan
Write-Host "Output: gs://$BUCKET_NAME/output/" -ForegroundColor Cyan
Write-Host ""
