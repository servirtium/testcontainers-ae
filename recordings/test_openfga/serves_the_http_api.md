## Interaction 0: GET /healthz

### Request headers recorded for playback:

```
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
Content-Type: application/json
Vary: Origin
```
### Response body recorded for playback (200: application/json):

```
{"status":"SERVING"}

```

## Interaction 1: POST /stores

### Request headers recorded for playback:

```
Content-Type: application/json
```
### Request body recorded for playback ():

```
{"name":"tcae"}
```
### Response headers recorded for playback:

```
Content-Type: application/json
Vary: Origin
X-Http-Code: 201
```
### Response body recorded for playback (201: application/json):

```
{"id":"{{store-id-1}}", "name":"tcae", "created_at":"2000-01-01T00:00:00Z", "updated_at":"2000-01-01T00:00:00Z"}
```

## Interaction 2: GET /stores

### Request headers recorded for playback:

```
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
Content-Type: application/json
Vary: Origin
```
### Response body recorded for playback (200: application/json):

```
{"stores":[{"id":"{{store-id-1}}", "name":"tcae", "created_at":"2000-01-01T00:00:00Z", "updated_at":"2000-01-01T00:00:00Z", "deleted_at":null}], "continuation_token":""}
```

## Interaction 3: GET /stores/{{store-id-1}}

### Request headers recorded for playback:

```
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
Content-Type: application/json
Openfga-Store-Id: {{store-id-1}}
Vary: Origin
```
### Response body recorded for playback (200: application/json):

```
{"id":"{{store-id-1}}", "name":"tcae", "created_at":"2000-01-01T00:00:00Z", "updated_at":"2000-01-01T00:00:00Z", "deleted_at":null}
```

