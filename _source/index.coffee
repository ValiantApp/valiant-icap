ICAPServer = require('nodecap').ICAPServer
DomainList = require('nodecap').DomainList

whitelist = new DomainList()
whitelist.addMany [
  'google.com'
]

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
  console.log 'request'
  icapRes.setIcapStatusCode 200
  icapRes.setIcapHeaders
    'Methods': 'REQMOD'
    'Preview': '128'
  icapRes.writeHeaders false
  icapRes.end()
  return

#  RESPMOD
server.options '/response', (icapReq, icapRes, next) ->
  console.log 'response'
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

#  handlers
#  accept request/response if domain on whitelist
# server.request whitelist, acceptRequest
# server.response whitelist, acceptRequest

#  reject otherwise
server.request '*', rejectRequest
server.response '*', rejectRequest

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

