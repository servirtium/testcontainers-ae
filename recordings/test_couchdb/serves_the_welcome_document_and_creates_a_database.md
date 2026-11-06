## Interaction 0: GET /

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
Cache-Control: must-revalidate
Content-Length: 247
Content-Type: application/json
Server: CouchDB/3.5.3 (Erlang OTP/27)
```
### Response body recorded for playback (200: application/json):

```
{"couchdb":"Welcome","version":"3.5.3","git_sha":"7a1f97558","uuid":"{{couchdb-uuid-1}}","features":["access-ready","partitioned","pluggable-storage-engines","reshard","scheduler"],"vendor":{"name":"The Apache Software Foundation"}}

```

## Interaction 1: GET /_up

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
Cache-Control: must-revalidate
Content-Length: 27
Content-Type: application/json
Server: CouchDB/3.5.3 (Erlang OTP/27)
```
### Response body recorded for playback (200: application/json):

```
{"seeds":{},"status":"ok"}

```

## Interaction 2: PUT /tcae_db

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
Cache-Control: must-revalidate
Content-Length: 64
Content-Type: application/json
Server: CouchDB/3.5.3 (Erlang OTP/27)
```
### Response body recorded for playback (401: application/json):

```
{"error":"unauthorized","reason":"You are not a server admin."}

```

## Interaction 3: PUT /tcae_db

### Request headers recorded for playback:

```
Authorization: Basic REDACTED[admin-wrong-password]
Connection: keep-alive
Host: {{request.host}}
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

## Interaction 4: PUT /tcae_db

### Request headers recorded for playback:

```
Authorization: Basic REDACTED[admin]
Connection: keep-alive
Host: {{request.host}}
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
Cache-Control: must-revalidate
Content-Length: 12
Content-Type: application/json
Location: http://{{request.host}}/tcae_db
Server: CouchDB/3.5.3 (Erlang OTP/27)
```
### Response body recorded for playback (201: application/json):

```
{"ok":true}

```

## Interaction 5: GET /tcae_db

### Request headers recorded for playback:

```
Authorization: Basic REDACTED[admin]
Connection: keep-alive
Host: {{request.host}}
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
Cache-Control: must-revalidate
Content-Length: 464
Content-Type: application/json
Server: CouchDB/3.5.3 (Erlang OTP/27)
```
### Response body recorded for playback (200: application/json):

```
{"instance_start_time":"946684800","db_name":"tcae_db","purge_seq":"0-SEQ","update_seq":"0-SEQ","sizes":{"file":16692,"external":0,"active":0},"props":{},"doc_del_count":0,"doc_count":0,"disk_format_version":8,"compact_running":false,"cluster":{"q":2,"n":1,"w":1,"r":1}}

```

