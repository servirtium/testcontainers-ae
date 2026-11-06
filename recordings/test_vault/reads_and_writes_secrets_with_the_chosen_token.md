## Interaction 0: GET /v1/sys/health

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
Cache-Control: no-store
Content-Type: application/json
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Length: 295
```
### Response body recorded for playback (200: application/json):

```
{"initialized":true,"sealed":false,"standby":false,"performance_standby":false,"replication_performance_mode":"disabled","replication_dr_mode":"disabled","server_time_utc":946684800,"version":"1.13.0","cluster_name":"vault-cluster-0","cluster_id":"{{uuid-1}}"}

```

## Interaction 1: GET /v1/secret/data/test1

### Request headers recorded for playback:

```
Connection: keep-alive
Host: {{request.host}}
X-Vault-Token: REDACTED-TOKEN
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
Cache-Control: no-store
Content-Type: application/json
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Length: 315
```
### Response body recorded for playback (200: application/json):

```
{"request_id":"{{uuid-2}}","lease_id":"","renewable":false,"lease_duration":0,"data":{"data":{"foo1":"bar1"},"metadata":{"created_time":"2000-01-01T00:00:00Z","custom_metadata":null,"deletion_time":"","destroyed":false,"version":1}},"wrap_info":null,"warnings":null,"auth":null}

```

## Interaction 2: GET /v1/transit/keys/my-key

### Request headers recorded for playback:

```
Connection: keep-alive
Host: {{request.host}}
X-Vault-Token: REDACTED-TOKEN
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
Cache-Control: no-store
Content-Type: application/json
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Length: 561
```
### Response body recorded for playback (200: application/json):

```
{"request_id":"{{uuid-3}}","lease_id":"","renewable":false,"lease_duration":0,"data":{"allow_plaintext_backup":false,"auto_rotate_period":0,"deletion_allowed":false,"derived":false,"exportable":false,"imported_key":false,"keys":{"1":946684800},"latest_version":1,"min_available_version":0,"min_decryption_version":1,"min_encryption_version":0,"name":"my-key","supports_decryption":true,"supports_derivation":true,"supports_encryption":true,"supports_signing":false,"type":"aes256-gcm96"},"wrap_info":null,"warnings":null,"auth":null}

```

## Interaction 3: POST /v1/secret/data/test3

### Request headers recorded for playback:

```
Connection: keep-alive
Content-Length: 22
Content-Type: application/json
Host: {{request.host}}
X-Vault-Token: REDACTED-TOKEN
```
### Request body recorded for playback ():

```
{"data":{"foo":"bar"}}
```
### Response headers recorded for playback:

```
Cache-Control: no-store
Content-Type: application/json
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Length: 279
```
### Response body recorded for playback (200: application/json):

```
{"request_id":"{{uuid-4}}","lease_id":"","renewable":false,"lease_duration":0,"data":{"created_time":"2000-01-01T00:00:00Z","custom_metadata":null,"deletion_time":"","destroyed":false,"version":1},"wrap_info":null,"warnings":null,"auth":null}

```

## Interaction 4: GET /v1/secret/data/test3

### Request headers recorded for playback:

```
Connection: keep-alive
Host: {{request.host}}
X-Vault-Token: REDACTED-TOKEN
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
Cache-Control: no-store
Content-Type: application/json
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Length: 313
```
### Response body recorded for playback (200: application/json):

```
{"request_id":"{{uuid-5}}","lease_id":"","renewable":false,"lease_duration":0,"data":{"data":{"foo":"bar"},"metadata":{"created_time":"2000-01-01T00:00:00Z","custom_metadata":null,"deletion_time":"","destroyed":false,"version":1}},"wrap_info":null,"warnings":null,"auth":null}

```

## Interaction 5: GET /v1/secret/data/test1

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
Cache-Control: no-store
Content-Type: application/json
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Length: 33
```
### Response body recorded for playback (403: application/json):

```
{"errors":["permission denied"]}

```

## Interaction 6: GET /v1/secret/data/test1

### Request headers recorded for playback:

```
Connection: keep-alive
Host: {{request.host}}
X-Vault-Token: not-the-token
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
Cache-Control: no-store
Content-Type: application/json
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Length: 33
```
### Response body recorded for playback (403: application/json):

```
{"errors":["permission denied"]}

```

