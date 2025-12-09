# Prototypes

This folder contains work-in-progress scripts for testing and perfecting examples.

## Files

- **`prediction_visualizer.lua`** - Draws predicted movement path for local player
- **`deploy.ps1`** - Deploys .lua files to Lmaobox (triggered by Run on Save extension)

## Usage

### Auto-Deploy Setup

Uses "Run on Save" VSCode extension - saves and deploys automatically!

1. Install extension: `emeraldwalk.RunOnSave`
2. Settings already configured in `.vscode/settings.json`
3. Just edit and save - it deploys automatically!

Files deploy to:

```
C:\Users\Terminatort8000\AppData\Local\lua\
```

### Manual Deploy (Optional)

Deploy all .lua files:

```powershell
.\deploy.ps1
```

### Test In-Game

1. Launch TF2 with Lmaobox
2. Load the script from the Lua menu
3. See your changes live as you edit!

## Prediction Visualizer

Shows a colored path of where you'll be in the next 30 ticks:

- **Green** → Near future (0-10 ticks)
- **Yellow** → Mid future (10-20 ticks)
- **Red** → Far future (20-30 ticks)

Displays:

- Current speed
- Ground status
- Prediction time

Perfect for debugging movement prediction accuracy!

## Tips

- Edit scripts in your favorite editor
- Save triggers auto-deploy (watch the PowerShell window)
- Use `lua_reload` in console or rebind to see changes instantly
- Add more prototypes as needed
