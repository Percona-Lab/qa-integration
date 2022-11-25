### Example curl to trigger ci.yml workflow

```shell
curl -v -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token ${GITHUB_API_TOKEN}" \
    "https://api.github.com/repos/Percona-Lab/qa-integration/actions/workflows/ci.yml/dispatches" \
    -d '{"ref":"main","inputs":{"text":"Hello from jenkins"}}'
```
