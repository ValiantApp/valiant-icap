ICAPServer = require('nodecap').ICAPServer
https = require 'https'
METACERT_KEY = process.env.METACERT_KEY

server = new ICAPServer
  debug: false

console.log 'Starting ICAP Server'
server.listen (port) ->
  console.log 'ICAP server listening on port ' + port

#  configure options
#    to have different options for requests and responses,
#    configure squid to send these to different ICAP resource paths
#  REQMOD
server.options '/request', (icapReq, icapRes, next) ->
  icapRes.setIcapStatusCode 200
  icapRes.setIcapHeaders
    'Methods': 'REQMOD'
    'Preview': '128'
  icapRes.writeHeaders false
  icapRes.end()
  return

#  RESPMOD
server.options '/response', (icapReq, icapRes, next) ->
  icapRes.setIcapStatusCode 200
  icapRes.setIcapHeaders
    'Methods': 'RESPMOD'
    'Preview': '128'
    'Transfer-Preview': '*'
    'Transfer-Ignore': 'jpg,jpeg,gif,png'
    'Transfer-Complete': ''
    'Max-Connections': '100'
  icapRes.writeHeaders false
  icapRes.end()
  return

#  return error if options path not recognized
server.options '*', (icapReq, icapRes, next) ->
  if !icapRes.done
    icapRes.setIcapStatusCode 404
    icapRes.writeHeaders false
    icapRes.end()
    return
  next()
  return

#  helper to accept a request/response
acceptRequest = (icapReq, icapRes, req, res) ->
  if !icapRes.hasFilter() and icapReq.hasPreview()
    icapRes.allowUnchanged()
    return
  icapRes.setIcapStatusCode 200
  icapRes.setIcapHeaders icapReq.headers
  if icapReq.isReqMod()
    icapRes.setHttpMethod req
    icapRes.setHttpHeaders req.headers
  else
    icapRes.setHttpMethod res
    icapRes.setHttpHeaders res.headers
  icapRes.writeHeaders icapReq.hasBody()
  icapReq.pipe icapRes
  return

#  helper to reject a request/response
rejectRequest = (icapReq, icapRes, req, res) ->
  errorPage = '
    <html>
      <head><title>Valiant Error</title></head>
      <body>
        <h1>Blocked</h1>
      </body>
    </html>
    '
  hasBody = false
  headers = {}
  # do *not* set Content-Length: causes an issue with Squid
  if req.headers and 'Accept' of req.headers and req.headers['Accept'].indexOf('text') >= 0
    hasBody = true
    headers['Content-Type'] = 'text/html; charset=UTF-8'
  icapRes.setIcapStatusCode 200
  icapRes.setIcapHeaders icapReq.headers
  icapRes.setHttpStatus 403
  icapRes.setHttpHeaders headers
  if hasBody
    icapRes.writeHeaders true
    icapRes.send errorPage
  else
    icapRes.writeHeaders false
  return

handleRequest = (icapReq, icapRes, req, res) ->

  xxx = false

  options =
    host: 'dev.metacert.com'
    path: '/v4/check/'
    method: 'POST'
    headers:
      apikey: METACERT_KEY
      'Content-Type': 'application/json'

  callback = (response) ->
    str = ''
    response.on 'data', (chunk) ->
      str += chunk
    response.on 'end', ->
      str = JSON.parse str
      str.data.Domains.forEach (domain) ->
        xxx = true if domain.type is 'xxx'

      if xxx
        rejectRequest icapReq, icapRes, req, res
      else
        acceptRequest icapReq, icapRes, req, res

  data =
    url: req.uri

  request = https.request options, callback
  request.write JSON.stringify(data)
  request.end()


server.request '*', handleRequest
server.response '*', handleRequest

#  errors
#  icap error
server.error (err, icapReq, icapRes, next) ->
  console.error err
  if !icapRes.done
    icapRes.setIcapStatusCode 500
    icapRes.writeHeaders false
    icapRes.end()
  next()
  return

#  general application error
process.on 'uncaughtException', (err) ->
  console.error err.message
  if err.stack
    console.error err.stack
  process.exit 1
  return

