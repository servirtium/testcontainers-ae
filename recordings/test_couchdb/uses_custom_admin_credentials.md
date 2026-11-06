## Interaction 0: PUT /custom_db

### Request headers recorded for playback:

```
Authorization: Basic REDACTED[testuser]
Connection: keep-alive
Host: {{request.host}}
User-Agent: testcontainers-ae-tests (Aether std.http.client)
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
Cache-Control: must-revalidate
Content-Length: 12
Content-Type: application/json
Location: http://{{request.host}}/custom_db
Server: CouchDB/3.5.3 (Erlang OTP/27)
```
### Response body recorded for playback (201: application/json):

```
{"ok":true}

```

## Interaction 1: PUT /other_db

### Request headers recorded for playback:

```
Authorization: Basic REDACTED[admin]
Connection: keep-alive
Host: {{request.host}}
User-Agent: testcontainers-ae-tests (Aether std.http.client)
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
Cache-Control: must-revalidate
Content-Length: 67
Content-Type: application/json
Server: CouchDB/3.5.3 (Erlang OTP/27)
```
### Response body recorded for playback (401: application/json):

```
{"error":"unauthorized","reason":"Name or password is incorrect."}

```

