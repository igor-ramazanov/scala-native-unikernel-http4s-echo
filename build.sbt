import scala.scalanative.build._

lazy val versions = new {
  val cats       = "2.13.0"
  // cats-effect, 5d101154023e commit, locally published
  val fs2        = "3.13.0-M8"
  val catsEffect = "3.7.0"
  // http4s, 14130b66551f commit, locally published
  val http4s     = "0.23.33-115-14130b6-20260302T222621Z-SNAPSHOT"
  val ip4s       = "3.8.0-RC3"
  val scala      = "3.8.2"
}

def addCommandsAlias(name: String, commands: List[String]) = addCommandAlias(name, commands.mkString(";"))

addCommandsAlias(
  "dependencyCheck",
  List(
    "reload plugins",
    "dependencyUpdates",
    "reload return",
    "dependencyUpdates",
    "undeclaredCompileDependencies",
    "unusedCompileDependencies",
  ),
)

addCommandsAlias(
  "validate",
  List(
    "scalafmtSbtCheck",
    "scalafmtCheckAll",
    "scalafixAll --check",
    "undeclaredCompileDependenciesTest",
    "unusedCompileDependenciesTest",
    "test",
  ),
)

addCommandsAlias("massage", List("scalafixAll", "scalafmtSbt", "scalafmtAll", "Test/compile"))

lazy val `unikernel-scala` = project
  .in(file("."))
  .enablePlugins(ScalaNativePlugin, BindgenPlugin)
  .settings(
    version           := java.nio.file.Files.readString(file("version").toPath()),
    organization      := "tech.igorramazanov.unikernel.scala",
    scalacOptions     :=
      List("-Wall", "-Werror", "-deprecation", "-feature", "-no-indent", "-old-syntax", "-source:future", "-unchecked"),
    scalafixOnCompile := false,
    semanticdbEnabled := true,
    semanticdbVersion := scalafixSemanticdb.revision,
    scalaVersion      := versions.scala,
    Compile / fork    := true,
    logLevel          := Level.Info,
    nativeConfig ~=
      (c =>
        // The rest is managed through env vars, check flake.nix
        c.withBuildTarget(BuildTarget.application)
          .withCheck(true)
          .withCheckFatalWarnings(true)
          .withCheckFeatures(true)
          .withCompileOptions("-static" :: Nil)
          .withDump(true)
          .withEmbedResources(true)
          .withGC(GC.commix) // Experiment by chaning this
          .withIncrementalCompilation(true)
          .withLTO(LTO.thin)
          .withLinkStubs(true)
          .withLinkingOptions("-static" :: Nil)
          .withMode(Mode.releaseFast)
          .withMultithreading(true)
          .withOptimize(true)
          .withSourceLevelDebuggingConfig(SourceLevelDebuggingConfig.enabled)
      ),
    libraryDependencies ++= List(
      "co.fs2"        %% "fs2-io"              % versions.fs2,
      "com.comcast"   %% "ip4s-core"           % versions.ip4s,
      "org.http4s"    %% "http4s-core"         % versions.http4s,
      "org.http4s"    %% "http4s-dsl"          % versions.http4s,
      "org.http4s"    %% "http4s-ember-server" % versions.http4s,
      "org.http4s"    %% "http4s-server"       % versions.http4s,
      "org.typelevel" %% "cats-core"           % versions.cats,
      "org.typelevel" %% "cats-effect"         % versions.catsEffect,
      "org.typelevel" %% "cats-effect-kernel"  % versions.catsEffect,
    ).map(dep => dep.withName(dep.name + "_native0.5")),
  )
