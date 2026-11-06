## Interaction 0: GET /health

### Request headers recorded for playback:

```
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
access-control-allow-origin: *
content-type: application/json; charset=utf-8
```
### Response body recorded for playback (200: application/json; charset=utf-8):

```
{"ok":true}
```

## Interaction 1: POST /collections

### Request headers recorded for playback:

```
Content-Type: application/json
X-TYPESENSE-API-KEY: REDACTED[wrong-key]
```
### Request body recorded for playback ():

```
{"name":"companies","fields":[{"name":"company_name","type":"string"},{"name":"num_employees","type":"int32"}],"default_sorting_field":"num_employees"}
```
### Response headers recorded for playback:

```
access-control-allow-origin: *
content-type: application/json; charset=utf-8
```
### Response body recorded for playback (401: application/json; charset=utf-8):

```
{"message": "Forbidden - a valid `x-typesense-api-key` header must be sent."}
```

## Interaction 2: POST /collections

### Request headers recorded for playback:

```
Content-Type: application/json
X-TYPESENSE-API-KEY: REDACTED[test-api-key]
```
### Request body recorded for playback ():

```
{"name":"companies","fields":[{"name":"company_name","type":"string"},{"name":"num_employees","type":"int32"}],"default_sorting_field":"num_employees"}
```
### Response headers recorded for playback:

```
access-control-allow-origin: *
content-type: application/json; charset=utf-8
```
### Response body recorded for playback (201: application/json; charset=utf-8):

```
{"created_at":946684800,"default_sorting_field":"num_employees","enable_nested_fields":false,"fields":[{"facet":false,"index":true,"infix":false,"locale":"","name":"company_name","optional":false,"sort":false,"stem":false,"type":"string"},{"facet":false,"index":true,"infix":false,"locale":"","name":"num_employees","optional":false,"sort":true,"stem":false,"type":"int32"}],"name":"companies","num_documents":0,"symbols_to_index":[],"token_separators":[]}
```

## Interaction 3: GET /collections/companies

### Request headers recorded for playback:

```
X-TYPESENSE-API-KEY: REDACTED[test-api-key]
```
### Request body recorded for playback ():

```
```
### Response headers recorded for playback:

```
access-control-allow-origin: *
content-type: application/json; charset=utf-8
```
### Response body recorded for playback (200: application/json; charset=utf-8):

```
{"created_at":946684800,"default_sorting_field":"num_employees","enable_nested_fields":false,"fields":[{"facet":false,"index":true,"infix":false,"locale":"","name":"company_name","optional":false,"sort":false,"stem":false,"type":"string"},{"facet":false,"index":true,"infix":false,"locale":"","name":"num_employees","optional":false,"sort":true,"stem":false,"type":"int32"}],"name":"companies","num_documents":0,"symbols_to_index":[],"token_separators":[]}
```

