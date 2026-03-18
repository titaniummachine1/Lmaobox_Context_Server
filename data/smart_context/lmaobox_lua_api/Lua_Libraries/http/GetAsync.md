## Function/Symbol: http.GetAsync

> Perform asynchronous HTTP GET request with callback

### Curated Usage Examples

```lua
http.GetAsync("https://api.example.com/data", function(response)
    print("Got response: " .. response)
end)
```

### Notes

- Non-blocking; callback runs when response arrives
- Prefer for long requests to avoid freezing

