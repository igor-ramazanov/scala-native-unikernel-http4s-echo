package tech.igorramazanov.unikernel.scala

import cats.*
import cats.effect.*
import cats.syntax.all.*
import com.comcast.ip4s.*
import org.http4s.*
import org.http4s.dsl.io.*
import org.http4s.ember.server.*
import org.typelevel.log4cats.*
import org.typelevel.log4cats.noop.*

object Main extends ResourceApp.Forever:
  private given LoggerFactory[IO] = NoOpFactory[IO]
  private given Show[Request[IO]] = Show.fromToString

  override def run(args: List[String]): Resource[IO, Unit] = EmberServerBuilder
    .default[IO]
    .withHost(host"0.0.0.0")
    .withPort(port"80")
    .withHttp2
    .withHttpApp:
      HttpRoutes
        .of[IO]: req =>
          Ok:
            show"Hello from Scala Native NanoVM Unikernel! Your request: $req"
        .orNotFound
    .build
    .void
