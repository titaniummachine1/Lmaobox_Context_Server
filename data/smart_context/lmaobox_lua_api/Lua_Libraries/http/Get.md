## Function/Symbol: http.Get

> Perform synchronous HTTP GET request

### Curated Usage Examples

```lua
local response = http.Get("https://api.example.com/data")
if response then
    print("Response: " .. response)
end
```

### Notes

- Blocks script until response; use GetAsync for non-blocking

