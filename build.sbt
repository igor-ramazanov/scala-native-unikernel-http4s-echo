import scala.scalanative.build._

lazy val versions = new {
  val cats       = "2.11.0" // The last version published against Scala Native 0.4.x
  val catsEffect = "3.6.0-RC1"
  val fs2        = "3.12.0-RC1"
  val http4s     = "1.0.0-M44"
  val ip4s       = "3.6.0"
  val log4cats   = "2.7.0"
  val scala      = "3.6.3"
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
      List("-deprecation", "-feature", "-new-syntax", "-rewrite", "-unchecked", "-Wall", "-Wunused:imports"),
    scalafixOnCompile := true,
    semanticdbEnabled := true,
    semanticdbVersion := scalafixSemanticdb.revision,
    scalaVersion      := versions.scala,
    Compile / fork    := true,
    logLevel          := Level.Info,
    nativeConfig ~=
      (c =>
        // The rest is managed through env vars, check flake.nix
        c.withBuildTarget(BuildTarget.application)
          .withCheckFatalWarnings(true)
          .withCheck(true)
          .withEmbedResources(false)
          .withIncrementalCompilation(true)
          .withLinkStubs(true)
      ),
    libraryDependencies ++= List(
      "co.fs2"        %%% "fs2-core"            % versions.fs2,
      "co.fs2"        %%% "fs2-io"              % versions.fs2,
      "com.comcast"   %%% "ip4s-core"           % versions.ip4s,
      "org.http4s"    %%% "http4s-core"         % versions.http4s,
      "org.http4s"    %%% "http4s-dsl"          % versions.http4s,
      "org.http4s"    %%% "http4s-ember-server" % versions.http4s,
      "org.http4s"    %%% "http4s-server"       % versions.http4s,
      "org.typelevel" %%% "cats-core"           % versions.cats,
      "org.typelevel" %%% "cats-effect-kernel"  % versions.catsEffect,
      "org.typelevel" %%% "cats-effect"         % versions.catsEffect,
      "org.typelevel" %%% "log4cats-core"       % versions.log4cats,
    ),
  )
