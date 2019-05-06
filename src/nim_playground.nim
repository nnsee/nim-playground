import jester, asyncdispatch, os, osproc, strutils, json, threadpool, asyncfile, asyncnet, posix, logging, nuuid, tables, httpclient, streams, uri

type
  Config = object
    tmpDir: ptr string
    logFile: ptr string

  APIToken = object
    gist: string

  ParsedRequest = object
    code: string
    compilationTarget: string

  RequestConfig = object
    tmpDir: string

const configFileName = "conf.json"

onSignal(SIGABRT):
  ## Handle SIGABRT from systemd
  # Lines printed to stdout will be received by systemd and logged
  # Start with "<severity>" from 0 to 7
  echo "<2>Received SIGABRT"
  quit(1)

var conf = createShared(Config)
let parsedConfig = parseFile(configFileName)
var
  tmpDir = parsedConfig["tmp_dir"].str
  logFile = parsedConfig["log_fname"].str

discard existsOrCreateDir(tmpDir)

conf.tmpDir = tmpDir.addr
conf.logFile = logFile.addr

let fl = newFileLogger(conf.logFile[], fmtStr = "$datetime $levelname ")
fl.addHandler

proc respondOnReady(fv: FlowVar[TaintedString], requestConfig: ptr RequestConfig): Future[string] {.async.} =
  while true:
    if fv.isReady:
      echo ^fv

      var errorsFile = openAsync("$1/errors.txt" % requestConfig.tmpDir, fmRead)
      var logFile = openAsync("$1/logfile.txt" % requestConfig.tmpDir, fmRead)
      var errors = await errorsFile.readAll()
      var log = await logFile.readAll()

      var ret = %* {"compileLog": errors, "log": log}

      errorsFile.close()
      logFile.close()
      removeDir(requestConfig.tmpDir)
      freeShared(requestConfig)
      return $ret


    await sleepAsync(500)

proc prepareAndCompile(code, compilationTarget: string, requestConfig: ptr RequestConfig): TaintedString =
  discard existsOrCreateDir(requestConfig.tmpDir)
  copyFileWithPermissions("./test/script.sh", "$1/script.sh" % requestConfig.tmpDir)
  writeFile("$1/in.nim" % requestConfig.tmpDir, code)

  execProcess("""
    ./docker_timeout.sh 20s -i -t --net=none -v "$1":/usercode virtual_machine /usercode/script.sh in.nim $2
    """ % [requestConfig.tmpDir, compilationTarget])

proc loadUrl(url: string): Future[string] {.async.} =
  let client = newAsyncHttpClient()
  client.onProgressChanged = proc (total, progress, speed: BiggestInt) {.async.} =
    if total > 1048576 or progress > 1048576 or (progress > 4000 and speed < 100):
      client.close()
  return await client.getContent(url)

proc createIx(code: string): string =
  let client = newHttpClient()
  var data = newMultipartData()
  data["f:1"] = code
  client.postContent("http://ix.io", multipart = data)[0..^2] & "/nim"

proc loadIx(ixid: string): Future[string] {.async.} =
  try:
    return await loadUrl("http://ix.io/$1" % ixid)
  except:
    return "Unable to load ix paste, file too large, or download is too slow"

proc compile(code, compilationTarget: string, requestConfig: ptr RequestConfig): Future[string] =
  let fv = spawn prepareAndCompile(code, compilationTarget, requestConfig)
  return respondOnReady(fv, requestConfig)

routes:
  get "/":
    redirect("/index.html")

  get "/tour/@url":
      resp(Http200, [("Content-Type","text/plain")], await loadUrl(decodeUrl(@"url")))

  get "/ix/@ixid":
      resp(Http200, await loadIx(@"ixid"))

  post "/ix":
    var parsedRequest: ParsedRequest
    let parsed = parseJson(request.body)
    if getOrDefault(parsed, "code").isNil:
      resp(Http400)
    parsedRequest = to(parsed, ParsedRequest)

    resp(Http200, @[("Access-Control-Allow-Origin", "*"), ("Access-Control-Allow-Methods", "POST")], createix(parsedRequest.code))

  post "/compile":
    var parsedRequest: ParsedRequest

    if request.params.len > 0:
      if request.params.hasKey("code"):
        parsedRequest.code = request.params["code"]
      if request.params.hasKey("compilationTarget"):
        parsedRequest.compilationTarget = request.params["compilationTarget"]
    else:
      let parsed = parseJson(request.body)
      if getOrDefault(parsed, "code").isNil:
        resp(Http400)
      if getOrDefault(parsed, "compilationTarget").isNil:
        resp(Http400)
      parsedRequest = to(parsed, ParsedRequest)

    let requestConfig = createShared(RequestConfig)
    requestConfig.tmpDir = conf.tmpDir[] & "/" & generateUUID()
    let compileResult = await compile(parsedRequest.code, parsedRequest.compilationTarget, requestConfig)

    resp(Http200, [("Access-Control-Allow-Origin", "*"), ("Access-Control-Allow-Methods", "POST")], compileResult)


info "Starting!"
runForever()
freeShared(conf)
