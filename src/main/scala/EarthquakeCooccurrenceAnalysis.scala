import org.apache.spark.SparkConf
import org.apache.spark.sql.SparkSession
import org.apache.spark.rdd.RDD
import scala.math.BigDecimal
import scala.collection.mutable

object EarthquakeCooccurrenceAnalysis {

  def main(args: Array[String]): Unit = {
    // configurazione input, output e partizioni
    if (args.length < 2) {
      println("ERROR: Arguments needed: <InputPath> <OutputPath> [NumPartitions]")
      sys.exit(1)
    }

    val inputPath = args(0)
    val outputPath = args(1)
    val numPartitions = if (args.length > 2) args(2).toInt else 4

    println(s"Configuration:")
    println(s"  Input: $inputPath")
    println(s"  Output: $outputPath")
    println(s"  Partitions: $numPartitions")

    val sparkConf = new SparkConf().setAppName("EarthquakeCoooccurrenceAnalysis")
    if (!sparkConf.contains("spark.master")) sparkConf.setMaster("local[*]")

    val spark = SparkSession.builder().config(sparkConf).getOrCreate()

    try {
      val startTime = System.nanoTime()

      val inputRDD: RDD[(String, (Double, Double))] = spark.sparkContext
        .textFile(inputPath)
        .flatMap(parseLine)

      val totalRecords = inputRDD.count()
      println(s"[RECORDS] Parsed $totalRecords earthquake records")

      // repartition
      val repartitionedRDD = inputRDD.repartition(numPartitions)
      println(s"[PARTITIONS] Repartitioned to $numPartitions partitions")

      // calcola coppia con max co-occorrenze
      val ((loc1, loc2), datesList) = PairCounter.computeMaxCooccurrence(repartitionedRDD, numPartitions)

      val (loc1Lat, loc1Lon) = loc1
      val (loc2Lat, loc2Lon) = loc2

      // stampa coordinate nel log
      val coordinateLine = s"(($loc1Lat, $loc1Lon), ($loc2Lat, $loc2Lon))"
      println(s"\n========================================")
      println(s"[RESULT] Winning pair: $coordinateLine")
      println(s"[RESULT] Number of co-occurrences: ${datesList.length}")
      println(s"========================================\n")

      // salva solo le date nel file, per non creare log troppo lunghi
      spark.sparkContext
        .parallelize(datesList)
        .repartition(1)
        .saveAsTextFile(outputPath)

      println(s"[OUTPUT] Results saved to $outputPath")
      println(s"[OUTPUT] File contains ${datesList.length} dates")

      val duration = (System.nanoTime() - startTime) / 1e9
      println(f"[TIMING] Execution completed in $duration%.2f seconds")

    } finally {
      spark.stop()
    }
  }

  /**
   * Parse CSV line: latitude, longitude, date
   * Returns: (date, (lat, lon))
   *
   * Specifiche:
   * - Approssima lat/lon alla prima cifra decimale con HALF_UP rounding
   * - Estrae solo la data (YYYY-MM-DD)
   * - Filtra le righe di header
   */
  def parseLine(line: String): Option[(String, (Double, Double))] = {
    try {
      // filtra header e righe vuote
      if (line.isEmpty || line.startsWith("latitude") || line.startsWith("longitude")) {
        return None
      }

      val parts = line.split(",")
      if (parts.length < 3) {
        return None
      }

      val lat = parts(0).trim.toDouble
      val lon = parts(1).trim.toDouble
      val dateStr = parts(2).trim

      // arrotonda a 1 cifra decimale
      val roundedLat = BigDecimal(lat).setScale(1, BigDecimal.RoundingMode.HALF_UP).toDouble
      val roundedLon = BigDecimal(lon).setScale(1, BigDecimal.RoundingMode.HALF_UP).toDouble

      // estrae data
      val date = dateStr.split(' ')(0)

      Some((date, (roundedLat, roundedLon)))

    } catch {
      case _: Throwable => None
    }
  }
}