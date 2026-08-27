POST {{base_url}}/render
Content-Type: application/json
{
  "markdown": "# Hello"
}
HTTP/1.1 201
[Captures]
token: header "X-Token"
[Asserts]
status == 201
