# valiant-icap-server

An ICAP server that can communicate with a squid proxy to filter requests based on calls to the MetaCert API.

## Getting Started

```
git clone
cd valiant-icap
export METACERT_KEY=key
docker pull sameersbn/squid:latest
docker run --name='squid' -it --rm -p 3128:3128 -v $(pwd)/squid.conf:/etc/squid3/squid.user.conf sameersbn/squid:latest
node index.js
curl -v http://google.com -x $(boot2docker ip):3128
```

## Building

```
npm install -g normajs
norma build
```
