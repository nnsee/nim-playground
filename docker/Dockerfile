FROM alpine:3.7 as builder

RUN apk add git gcc musl-dev

WORKDIR /build

RUN git clone https://github.com/nim-lang/Nim.git

RUN cd Nim && git checkout $(git tag --sort=v:refname | tail -n 1)

WORKDIR /build/Nim

RUN git clone --depth 1 https://github.com/nim-lang/csources.git

WORKDIR /build/Nim/csources

RUN sh build.sh

WORKDIR /build/Nim

RUN bin/nim c --skipUserCfg --skipParentCfg koch

RUN ./koch boot -d:release

RUN mkdir /build/result

RUN ./koch install /build/result

RUN ./koch nimble

##################################

FROM alpine:3.7 as installer

RUN apk add git gcc musl-dev libressl-dev

WORKDIR /installer

COPY --from=builder /build/result/* ./nim/

COPY --from=builder /build/Nim/bin/nimble ./nim/bin

ENV PATH=$PATH:/installer/nim/bin

COPY packages.nimble ./

RUN nimble install --nimbleDir:/installer/nimble -y --depsOnly

##################################

FROM alpine:3.7 as playground

RUN apk add gcc musl-dev

WORKDIR /playground

COPY --from=builder /build/result/* ./nim/

COPY --from=installer /installer/nimble/pkgs ./nimble

ENV PATH=$PATH:/playground/nim/bin

RUN mkdir /usercode && chown nobody:nobody /usercode

RUN chown -R nobody:nobody /playground/nimble
