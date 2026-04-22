## Callback: FrameStageNotify

> Called when frame stage changes (engine pipeline)

### Pattern

```lua
callbacks.Register("FrameStageNotify", "fsn_demo", function(stage)
    -- stage is integer / enum; use to order logic if needed
end)
```

### Notes

- Advanced; use when you need ordering vs. rendering/updates
