# valiant-icap-server

An ICAP server that can communicate with a squid proxy to filter requests based on calls to the MetaCert API.

## Getting Started

```
git clone
cd valiant-icap-server
export METACERT_KEY=key
docker pull sameersbn/squid:latest
docker run --name='squid' -it --rm -p 3128:3128 -v $(pwd)/squid.conf:/etc/squid3/squid.user.conf sameersbn/squid:latest
node index.js
```

## Building

```
npm install -g normajs
norma build
```
