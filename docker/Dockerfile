FROM alpine:3.7 as builder

RUN apk add git gcc musl-dev

WORKDIR /build

RUN git clone https://github.com/nim-lang/Nim.git

COPY curtag Nim

RUN cd Nim && git checkout $(cat curtag)

WORKDIR /build/Nim

RUN git clone https://github.com/nim-lang/csources.git

WORKDIR /build/Nim/csources

COPY curtag .

RUN git checkout $(cat curtag) || git checkout $(echo $(git tag) $(cat curtag) | sed 's/ /\n/g' | sed 's/v/0./' | sort -t. -n -k1,1 -k2,2 -k3,3 -k4,4 | sed 's/0./v/' | sed -n "/$(cat curtag)/q;p" | tail -n1)

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

RUN apk add gcc g++ musl-dev

RUN apk add lapack-dev # Requirement for arraymancer

RUN apk add pcre # Requirement for regex

WORKDIR /playground

COPY --from=builder /build/result/* ./nim/

COPY --from=installer /installer/nimble/pkgs ./nimble

ENV PATH=$PATH:/playground/nim/bin

RUN mkdir /usercode && chown nobody:nobody /usercode

RUN chown -R nobody:nobody /playground/nimble
