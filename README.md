# nim-playground

This is the back-end for the [Nim playground](https://play.nim-lang.org). The front-end can be found [here](https://github.com/PMunch/nim-playground-frontend). All code that is executed by the playground is run within a container. This container always run the latest release of Nim, and comes with a series of Nimble packages installed. The list of packages can be found in [this list](https://github.com/PMunch/nim-playground/blob/master/docker/packages.nimble), and if you want to add or remove one simply make a PR to this repo that changes this file.
