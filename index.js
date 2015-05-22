var ICAPServer, METACERT_KEY, acceptRequest, handleRequest, https, rejectRequest, server;

ICAPServer = require('nodecap').ICAPServer;

https = require('https');

METACERT_KEY = process.env.METACERT_KEY;

server = new ICAPServer({
    debug: false
});

console.log('Starting ICAP Server');

server.listen(function (port) {
    console.log("META", METACERT_KEY);
    return console.log('ICAP server listening on port ' + port);
});

server.options('/request', function (icapReq, icapRes, next) {
    icapRes.setIcapStatusCode(200);
    icapRes.setIcapHeaders({
        'Methods': 'REQMOD',
        'Preview': '128'
    });
    icapRes.writeHeaders(false);
    icapRes.end();
});

server.options('/response', function (icapReq, icapRes, next) {
    icapRes.setIcapStatusCode(200);
    icapRes.setIcapHeaders({
        'Methods': 'RESPMOD',
        'Preview': '128',
        'Transfer-Preview': '*',
        'Transfer-Ignore': 'jpg,jpeg,gif,png',
        'Transfer-Complete': '',
        'Max-Connections': '100'
    });
    icapRes.writeHeaders(false);
    icapRes.end();
});

server.options('*', function (icapReq, icapRes, next) {
    if (!icapRes.done) {
        icapRes.setIcapStatusCode(404);
        icapRes.writeHeaders(false);
        icapRes.end();
        return;
    }
    next();
});

acceptRequest = function (icapReq, icapRes, req, res) {
    if (!icapRes.hasFilter() && icapReq.hasPreview()) {
        icapRes.allowUnchanged();
        return;
    }
    icapRes.setIcapStatusCode(200);
    icapRes.setIcapHeaders(icapReq.headers);
    if (icapReq.isReqMod()) {
        icapRes.setHttpMethod(req);
        icapRes.setHttpHeaders(req.headers);
    } else {
        icapRes.setHttpMethod(res);
        icapRes.setHttpHeaders(res.headers);
    }
    icapRes.writeHeaders(icapReq.hasBody());
    icapReq.pipe(icapRes);
};

rejectRequest = function (icapReq, icapRes, req, res) {
    var hasBody, headers;
    hasBody = false;
    headers = {};
    if (req.headers && 'Accept' in req.headers && req.headers['Accept'].indexOf('text') >= 0) {
        hasBody = true;
        headers['Content-Type'] = 'text/html; charset=UTF-8';
    }
    icapRes.setIcapStatusCode(200);
    icapRes.setIcapHeaders(icapReq.headers);
    icapRes.setHttpStatus(403);
    icapRes.setHttpHeaders(headers);
    if (hasBody) {
        icapRes.writeHeaders(true);
        icapRes.send(errorPage);
    } else {
        icapRes.writeHeaders(false);
    }
};

handleRequest = function (icapReq, icapRes, req, res) {
    var callback, data, options, request, xxx;
    xxx = false;
    options = {
        host: 'dev.metacert.com',
        path: '/v4/check/',
        method: 'POST',
        headers: {
            apikey: METACERT_KEY,
            'Content-Type': 'application/json'
        }
    };
    callback = function (response) {
        var str;
        console.log("THIS", this);
        str = '';
        response.on('data', function (chunk) {
            return str += chunk;
        });
        return response.on('end', function () {
            str = JSON.parse(str);
            str.data.Domains.forEach(function (domain) {
                if (domain.type === 'xxx') {
                    return xxx = true;
                }
            });
            if (xxx) {
                return rejectRequest(icapReq, icapRes, req, res);
            } else {
                return acceptRequest(icapReq, icapRes, req, res);
            }
        });
    };
    data = {
        url: req.uri
    };
    request = https.request(options, callback);
    request.write(JSON.stringify(data));
    return request.end();
};

server.request('*', handleRequest);

server.response('*', handleRequest);

server.error(function (err, icapReq, icapRes, next) {
    console.error(err);
    if (!icapRes.done) {
        icapRes.setIcapStatusCode(500);
        icapRes.writeHeaders(false);
        icapRes.end();
    }
    next();
});

process.on('uncaughtException', function (err) {
    console.error(err.message);
    if (err.stack) {
        console.error(err.stack);
    }
    process.exit(1);
});