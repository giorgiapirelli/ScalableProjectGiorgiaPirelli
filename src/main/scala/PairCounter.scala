import org.apache.spark.rdd.RDD
import org.apache.spark.HashPartitioner

object PairCounter {

  def computeMaxCooccurrence(
                              data: RDD[(String, (Double, Double))],
                              numPartitions: Int
                            ): (((Double, Double), (Double, Double)), Seq[String]) = {

    // partiziona per data usando HashPartitioner
    val partitioned = data.partitionBy(new HashPartitioner(numPartitions))

    // raggruppa per data
    val grouped = partitioned.groupByKey()

    // genera coppie di locazioni per ogni data
    val pairs = grouped.flatMap { case (date, locationList) =>
      val locations = locationList.toSet.toList.sorted

      if (locations.size < 2) {
        Seq()
      } else {
        // Crea tutte le coppie non ordinate
        for {
          i <- locations.indices
          j <- i + 1 until locations.size
        } yield ((locations(i), locations(j)), date)
      }
    }

    // raggruppa per coppia e raccoglie le date
    val pairDates = pairs
      .groupByKey()
      .map { case ((loc1, loc2), dates) =>
        (loc1, loc2, dates.toSet)
      }

    // trova la coppia con il massimo numero di co-occorrenze
    val maxPair = pairDates
      .map { case (loc1, loc2, dates) => (dates.size, (loc1, loc2, dates)) }
      .reduce { (a, b) => if (a._1 >= b._1) a else b }
      ._2

    // ordina le date
    val sortedDates = maxPair._3.toSeq.sorted

    // ritorna: ((prima coordinata), (seconda coordinata)), date ordinate
    ((maxPair._1, maxPair._2), sortedDates)
  }
}