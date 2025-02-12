# Scala Native in NanoVM Unikernel
Exploring Scala Native + Nix Flakes + Nix Devshell + Direnv + NanoVM Unikernel.

* https://scala-native.org/en/latest
* https://github.com/numtide/devshell
* https://nixos-and-flakes.thiscute.world/nixos-with-flakes/introduction-to-flakes
* https://direnv.net
* https://github.com/typelevel/typelevel-nix
* https://nanovms.com

The Nix sets up the development environment with:
1. `clang`: C/C++ LLVM compiler https://clang.llvm.org
1. `jdk`: GraalVM Community Edition: https://www.graalvm.org
1. `metals`: Scala Metals LSP server: https://scalameta.org/metals
1. `sbt`: Scala Built Tool: https://www.scala-sbt.org/index.html
1. `scala-cli`: Scala command-line tool: https://scala-cli.virtuslab.org
1. `scala-fix`: Scala refactoring and linting tool for Scala: https://scalacenter.github.io/scalafix
1. `ops`: NanoVM Unikernel build tool: https://github.com/nanovms/ops
1. `qemu`: QEMU hypervisor: https://www.qemu.org

The `build.sbt` points to `clang` binaries provided by the `devshell`.


## TODOs
- [ ] Static ELF.
- [ ] Non-Nix friendly.
- [ ] Build and package with Nix Flakes.
- [ ] Automatically build and publish the ELF and the unikernel image.
- [ ] Continuous deployment to DigitalOcean.

## Note on Nix
You can use this repo without `nix` if all of the above provided by your own environment, but you will need to update the [`build.sbt`](./build.sbt).

As for `nix` users, `cd` into the repository directory and run `nix develop` to drop into the development environment.\
Or, if you have `direnv` installed, simply `cd` into the repository directory and do `direnv allow`.\
Now, whenever you `cd` into the repository directory the development environment will be activated automatically,
and erased when you `cd` out of the repository directory.

## Usage

Build the binary:\
`sbt nativeLink`.

Now, let's use the `ops` command to run it as a QEMU virtual machine packaged as unikernel.\
It binds to the port 80, so we'll need `sudo`:\
`sudo ops run --port 80 ./target/scala-3.6.3/unikernel-scala-out`.


In another terminal window:\
`curl localhost`.\
Output:
```
Hello from Scala Native NanoVM Unikernel! Your request: Request(method=GET, uri=/, httpVersion=HTTP/1.1, headers=Headers(Host: localhost, User-Agent: curl/8.11.0, Accept: */*), entity=Entity.Empty)
```

Packaging:\
`ops build ./target/scala-3.6.3/unikernel-scala-out`.

Verify the image created:\
`ops image list`.\
Output:
```
100% |████████████████████████████████████████|  [0s:0s]
100% |████████████████████████████████████████|  [0s:0s]
Bootable image file:/home/igor/.ops/images/unikernel-scala-out.img
```

The resulting image then can be deployed to any cloud hypervisor which uses QEMU, e.g. [DigitalOcean](https://digitalocean.com).:
1. "Create Droplet".
2. "Choose Image" -> "Custom Images".
3. "Add Image".
4. Upload your image from `~/.ops/images/unikernel-scala-out.img`.
5. Wait for uploading the image and verification.
6. On your image: "More" -> "Start Droplet".

The app is currently deployed as [`http://unikernel.igorramazanov.tech`](http://unikernel.igorramazanov.tech) (you can simply open it in the browser):
```
curl -v http://unikernel.igorramazanov.tech

* Host unikernel.igorramazanov.tech:80 was resolved.
* IPv6: (none)
* IPv4: 138.68.108.40
*   Trying 138.68.108.40:80...
* Connected to unikernel.igorramazanov.tech (138.68.108.40) port 80
* using HTTP/1.x
> GET / HTTP/1.1
> Host: unikernel.igorramazanov.tech
> User-Agent: curl/8.11.0
> Accept: */*
>
* Request completely sent off
< HTTP/1.1 200 OK
< Date: Wed, 12 Feb 2025 14:25:39 GMT
< Connection: keep-alive
< Content-Type: text/plain; charset=UTF-8
< Content-Length: 195
<
* Connection #0 to host unikernel.igorramazanov.tech left intact
Hello from Scala Native NanoVM Unikernel! Your request: Request(method=GET, uri=/, httpVersion=HTTP/1.1, headers=Headers(Host: unikernel.igorramazanov.tech, User-Agent: curl/8.11.0, Accept: */*))
```


## CI
This repo uses `nix` based GitHub actions for caching the development environment dependencies,
instead of the traditional approach with [`coursier/setup-action`](https://github.com/coursier/setup-action) and [`coursier/cache-action`](https://github.com/coursier/cache-action):
1. https://github.com/DeterminateSystems/nix-installer-action
1. https://github.com/DeterminateSystems/flake-checker-action
1. https://github.com/DeterminateSystems/magic-nix-cache-action

