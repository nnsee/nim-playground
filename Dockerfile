FROM nimlang/nim

RUN apt-get update && apt-get install build-essential -y
RUN mkdir /usercode && chown nobody:users /usercode
