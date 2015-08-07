ICAPServer = require('nodecap').ICAPServer
http = require 'sync-request'
fs = require 'fs'
METACERT_KEY = process.env.METACERT_KEY

errorPage = null
fs.readFile 'error-page.html', 'utf8', (err, data) ->
  throw err if err
  errorPage = data

server = new ICAPServer
  debug: false

console.log 'Starting ICAP Server'
server.listen (port) ->
  console.log 'ICAP server listening on port ' + port

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

  url = 'https://dev.metacert.com/v4/check'
  xxx = false

  options =
    headers:
      apikey: METACERT_KEY
    json:
      url: req.uri

  response = http('POST', url, options)
  body = JSON.parse(response.getBody('utf8'))
  body.data.Domains.forEach (domain) ->
    if domain.type is 'xxx'
      xxx = true
      return

  if xxx
    rejectRequest(icapReq, icapRes, req, res)
  else
    acceptRequest(icapReq, icapRes, req, res)


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

