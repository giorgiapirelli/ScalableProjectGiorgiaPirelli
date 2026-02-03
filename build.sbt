ThisBuild / scalaVersion := "2.12.15"

lazy val root = (project in file("."))
  .settings(
    name := "Speriamo",

    libraryDependencies ++= Seq(
      "org.apache.spark" %% "spark-core" % "3.5.0" % "provided",
      "org.apache.spark" %% "spark-sql" % "3.5.0" % "provided"
    )
  )
// Escludi file META-INF dal packaging
Compile / packageBin / mappings := {
  val original = (Compile / packageBin / mappings).value
  original.filter { case (file, path) =>
    !path.startsWith("META-INF/")
  }
}