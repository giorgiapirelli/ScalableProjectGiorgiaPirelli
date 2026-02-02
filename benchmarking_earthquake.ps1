# Earthquake Co-occurrence Analysis - Strong Scalability Benchmarking - Giorgia Pirelli

$PROJECT = "scalableproject-482714"
$REGION = "europe-west1"
$BUCKET = "terremoti-bucket-giorgiapirelli"
$JAR = "gs://$BUCKET/jars/earthquake-app.jar"
$INPUT = "gs://$BUCKET/dataset-earthquakes-full.csv"
$OUTPUT_BASE = "gs://$BUCKET/output"
#scegliere quale tipo di macchina utilizzare e rispettivi parametri
$MACHINE_TYPE = "n2-standard-4" #oppure n1-standard-2
$DISK_SIZE = "240" # oppure con 100
$WORKERS_LIST = @(2, 3) #se si utilizza n1-standard-2, viene aggiunto anche 4
$PARTITION_COUNTS = @(8, 16, 24) #partizioni

$CSV_FILE = "earthquake_scalability_results.csv"
"Workers,Partitions,PartitionsPerWorker,StartTime,EndTime,DurationSeconds,Status,OutputPath" | Out-File -FilePath $CSV_FILE -Encoding utf8

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Earthquake Co-occurrence Analysis" -ForegroundColor Cyan
Write-Host "Strong Scalability Benchmarking" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Project: $PROJECT" -ForegroundColor Gray
Write-Host "  Region: $REGION" -ForegroundColor Gray
Write-Host "  Machine Type: $MACHINE_TYPE" -ForegroundColor Gray
Write-Host "  Disk Size: $DISK_SIZE GB" -ForegroundColor Gray
Write-Host "  Workers: $($WORKERS_LIST -join ', ')" -ForegroundColor Gray
Write-Host "  Partitions: $($PARTITION_COUNTS -join ', ')" -ForegroundColor Gray
Write-Host ""

Write-Host "Preparing environment..." -ForegroundColor Magenta
Write-Host "  Removing previous output directories..." -ForegroundColor Gray
gcloud.cmd dataproc clusters delete earthquake-cluster --region=$REGION --project=$PROJECT --quiet 2>&1 | Out-Null
Start-Sleep -Seconds 2
gsutil.cmd -m rm -rf "$OUTPUT_BASE" 2>&1 | Out-Null
Start-Sleep -Seconds 2
Write-Host "  Environment ready" -ForegroundColor Green
Write-Host ""

foreach ($NUM_WORKERS in $WORKERS_LIST) {
    $CLUSTER = "earthquake-cluster"

    Write-Host ""
    Write-Host "===============================" -ForegroundColor Green
    Write-Host "Creating cluster with $NUM_WORKERS worker nodes..." -ForegroundColor Green
    Write-Host "===============================" -ForegroundColor Green

    gcloud.cmd dataproc clusters create $CLUSTER `
        --project=$PROJECT `
        --region=$REGION `
        --master-machine-type=$MACHINE_TYPE `
        --worker-machine-type=$MACHINE_TYPE `
        --master-boot-disk-size="${DISK_SIZE}GB" `
        --worker-boot-disk-size="${DISK_SIZE}GB" `
        --num-workers=$NUM_WORKERS `
        --quiet

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: cluster creation failed" -ForegroundColor Red
        foreach ($PARTITIONS in $PARTITION_COUNTS) {
            $PartPerWorker = [Math]::Floor($PARTITIONS / $NUM_WORKERS)
            "$NUM_WORKERS,$PARTITIONS,$PartPerWorker,N/A,N/A,0,FAILED,N/A" | Out-File -FilePath $CSV_FILE -Append -Encoding utf8
        }
        continue
    }

    Write-Host "cluster created successfully" -ForegroundColor Green
    Write-Host ""

    foreach ($NUM_PARTITIONS in $PARTITION_COUNTS) {
        $OUTPUT_DIR = "$OUTPUT_BASE/w${NUM_WORKERS}_p${NUM_PARTITIONS}"
        $PartitionsPerWorker = [Math]::Floor($NUM_PARTITIONS / $NUM_WORKERS)

        Write-Host "Running: Workers=$NUM_WORKERS, Partitions=$NUM_PARTITIONS" -ForegroundColor Yellow

        Write-Host "  Preparing output directory..." -ForegroundColor Gray
        # Force remove if exists
        gsutil.cmd -m rm -rf "$OUTPUT_DIR" 2>&1 | Out-Null
        Start-Sleep -Seconds 1
        # Verify directory is removed
        $dirExists = gcloud.cmd storage ls --project=$PROJECT "$OUTPUT_DIR" 2>&1 | Select-String "does not exist"
        if (-not $dirExists) {
            Write-Host "  Warning: Directory still exists, attempting harder cleanup..." -ForegroundColor Yellow
            gsutil.cmd -m rm -rf "$OUTPUT_DIR/*" 2>&1 | Out-Null
            Start-Sleep -Seconds 1
        }
        Write-Host "  Output directory ready" -ForegroundColor Green

        $JobStartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $Timer = [System.Diagnostics.Stopwatch]::StartNew()

        gcloud.cmd dataproc jobs submit spark `
            --cluster=$CLUSTER `
            --region=$REGION `
            --class=EarthquakeCooccurrenceAnalysis `
            --jars=$JAR `
            -- $INPUT "$OUTPUT_DIR" $NUM_PARTITIONS 2>&1 | Out-Null

        $Timer.Stop()
        $JobEndTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $Duration = [math]::Round($Timer.Elapsed.TotalSeconds, 2)
        $Status = if ($LASTEXITCODE -eq 0) { "SUCCESS" } else { "FAILED" }

        if ($Status -eq "SUCCESS") {
            Write-Host "  Completed: ${Duration}s" -ForegroundColor Cyan
        } else {
            Write-Host "  Failed" -ForegroundColor Red
        }

        "$NUM_WORKERS,$NUM_PARTITIONS,$PartitionsPerWorker,$JobStartTime,$JobEndTime,$Duration,$Status,$OUTPUT_DIR" | Out-File -FilePath $CSV_FILE -Append -Encoding utf8
        Write-Host ""
    }

    Write-Host "Deleting cluster..." -ForegroundColor Magenta
    gcloud.cmd dataproc clusters delete $CLUSTER --region=$REGION --project=$PROJECT --quiet 2>&1 | Out-Null
    Write-Host ""
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Benchmarking completed" -ForegroundColor Green
Write-Host "Results saved to: $CSV_FILE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if (Test-Path $CSV_FILE) {
    Write-Host "Summary Results:" -ForegroundColor Cyan
    Write-Host "================" -ForegroundColor Cyan
    Write-Host ""

    $results = Import-Csv $CSV_FILE
    $results | Format-Table -AutoSize

    $successfulJobs = $results | Where-Object { $_.Status -eq "SUCCESS" }

    if ($successfulJobs.Count -gt 0) {

        $groupedByPartitions = $successfulJobs | Group-Object -Property Partitions | Sort-Object Name

        foreach ($partGroup in $groupedByPartitions) {
            Write-Host "Partitions: $($partGroup.Name)" -ForegroundColor Yellow
            Write-Host "Workers | Time (s) | Speedup | Efficiency" -ForegroundColor Gray
            Write-Host "--------|----------|---------|----------" -ForegroundColor Gray

            $baseline = $partGroup.Group | Where-Object { [int]$_.Workers -eq 2 } | Select-Object -First 1
            if ($baseline) {
                $baselineTime = [double]$baseline.DurationSeconds
                foreach ($job in $partGroup.Group | Sort-Object { [int]$_.Workers }) {
                    $workers = [int]$job.Workers
                    $time = [double]$job.DurationSeconds

                    if ($workers -eq 2) {
                        # Baseline: Workers=2, Speedup=1.0, Efficiency=100%
                        $output = "   2    | {0:F2}   | 1.00x   | 100.0%" -f $time
                        Write-Host $output -ForegroundColor White
                    } else {
                        # S(n) = T(2) / T(n)
                        $speedup = [math]::Round($baselineTime / $time, 2)

                        # E(n) = (2/n) × [T(2) / T(n)] × 100
                        # Equivalente a: E(n) = (2/n) × S(n) × 100
                        $efficiency = [math]::Round((2.0 / $workers) * $speedup * 100, 1)

                        $output = "   $workers    | {0:F2}   | {1:F2}x   | $efficiency%" -f $time, $speedup
                        Write-Host $output -ForegroundColor Cyan
                    }
                }
            }
            Write-Host ""
        }
    }
}