## Interaction 0: GET /v1/status/leader

### Request headers recorded for playback:

```
Connection: keep-alive
Host: {{request.host}}
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
Content-Type: application/json
Vary: Accept-Encoding
X-Consul-Default-Acl-Policy: allow
Content-Length: 17
```
### Response body recorded for playback (200: application/json):

```
"127.0.0.1:8300"

```

## Interaction 1: PUT /v1/kv/tcae/greeting

### Request headers recorded for playback:

```
Connection: keep-alive
Content-Length: 12
Content-Type: application/json
Host: {{request.host}}
```
### Request body recorded for playback ():

```
hello consul
```
### Response headers recorded for playback:

```
Content-Type: application/json
Vary: Accept-Encoding
X-Consul-Default-Acl-Policy: allow
Content-Length: 5
```
### Response body recorded for playback (200: application/json):

```
true

```

## Interaction 2: GET /v1/kv/tcae/greeting?raw

### Request headers recorded for playback:

```
Connection: keep-alive
Host: {{request.host}}
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
Content-Length: 12
Content-Security-Policy: sandbox
Content-Type: text/plain
Vary: Accept-Encoding
X-Consul-Default-Acl-Policy: allow
X-Consul-Index: 1
X-Consul-Knownleader: true
X-Consul-Lastcontact: 0
X-Consul-Query-Backend: blocking-query
X-Content-Type-Options: nosniff
```
### Response body recorded for playback (200: text/plain):

```
hello consul
```

## Interaction 3: PUT /v1/agent/service/register

### Request headers recorded for playback:

```
Connection: keep-alive
Content-Length: 31
Content-Type: application/json
Host: {{request.host}}
```
### Request body recorded for playback ():

```
{"ID":"abcd","Name":"GoConfig"}
```
### Response headers recorded for playback:

```
Vary: Accept-Encoding
X-Consul-Default-Acl-Policy: allow
Content-Length: 0
```
### Response body recorded for playback (200: text/plain):

```
```

## Interaction 4: GET /v1/agent/services

### Request headers recorded for playback:

```
Connection: keep-alive
Host: {{request.host}}
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
Content-Type: application/json
Vary: Accept-Encoding
X-Consul-Default-Acl-Policy: allow
Content-Length: 306
```
### Response body recorded for playback (200: application/json):

```
{
    "abcd": {
        "ID": "abcd",
        "Service": "GoConfig",
        "Tags": [],
        "Meta": {},
        "Port": 0,
        "Address": "",
        "Weights": {
            "Passing": 1,
            "Warning": 1
        },
        "EnableTagOverride": false,
        "Datacenter": "dc1"
    }
}

```

## Interaction 5: PUT /v1/agent/service/deregister/abcd

### Request headers recorded for playback:

```
Connection: keep-alive
Host: {{request.host}}
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
Vary: Accept-Encoding
X-Consul-Default-Acl-Policy: allow
Content-Length: 0
```
### Response body recorded for playback (200: text/plain):

```
```

## Interaction 6: GET /v1/agent/services

### Request headers recorded for playback:

```
Connection: keep-alive
Host: {{request.host}}
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
Content-Type: application/json
Vary: Accept-Encoding
X-Consul-Default-Acl-Policy: allow
Content-Length: 3
```
### Response body recorded for playback (200: application/json):

```
{}

```

