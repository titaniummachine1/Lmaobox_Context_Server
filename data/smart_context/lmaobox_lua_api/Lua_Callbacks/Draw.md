## Callback: Draw

> Called every frame for rendering; use draw.\* here

### Pattern

```lua
callbacks.Register("Draw", "draw_demo", function()
    draw.Color(255, 255, 255, 255)
    draw.Text(10, 10, "Hello")
end)
```

### Notes

- Keep fast; avoid heavy loops per frame
- Use draw.GetScreenSize for positioning

### Matching Snippet

- Prefix: `lm.draw`

```lua
callbacks.Unregister("Draw", "unique_id")
callbacks.Register("Draw", "unique_id", function()
    draw.Color(255, 255, 255, 255)
    draw.Text(10, 10, "Hello")
end)
```
