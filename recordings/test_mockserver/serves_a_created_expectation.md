## Interaction 0: GET /hello

### Request headers recorded for playback:

```
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
```
### Response body recorded for playback (404: text/plain):

```
```

## Interaction 1: PUT /mockserver/expectation

### Request headers recorded for playback:

```
Content-Type: application/json
```
### Request body recorded for playback ():

```
{"httpRequest":{"method":"GET","path":"/hello"},"httpResponse":{"statusCode":200,"body":"Hello from tcae"}}
```
### Response headers recorded for playback:

```
version: 5.15.0
content-type: application/json; charset=utf-8
```
### Response body recorded for playback (201: application/json; charset=utf-8):

```
[ {
  "httpRequest" : {
    "method" : "GET",
    "path" : "/hello"
  },
  "httpResponse" : {
    "statusCode" : 200,
    "body" : "Hello from tcae"
  },
  "id" : "{{expectation-id-1}}",
  "priority" : 0,
  "timeToLive" : {
    "unlimited" : true
  },
  "times" : {
    "unlimited" : true
  }
} ]
```

## Interaction 2: GET /hello

### Request headers recorded for playback:

```
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
```
### Response body recorded for playback (200: text/plain):

```
Hello from tcae
```

## Interaction 3: GET /other

### Request headers recorded for playback:

```
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
```
### Response body recorded for playback (404: text/plain):

```
```

