# Settlers 5 AngusAI

This repo contains Settlers 5 scripts to setup an AI enemy in multiplayer games with ease. At the moment this is only tested using the second addon: **"Legends"** and the **"(4) Battle Isle"** map.

## Features

### Working

**Random Army Upgrades**
-> The AI is going to become stronger as the game goes on by upgrading its units.

### WIP

**Randomized Building Plan**
-> Randomize the building plans a bit to make the AI's settlement more unique.

**Randomized Research Plan**
-> Make the AI even more stronger with researching the unit improvements.

## How To

See the sample mapscript included in this repo. Either paste the AngusAI part into your mapscript or use the whole scipt on the **(4) Battle Isle** map (you can extract it using the bbaTool or get it from the *History Editions* maps folder).

If you want to use the script on the **(4) Battle Isle** map, make sure to change the AI's buildings to a playerId above 4, because they are reserved to player usage.

1.Call this at the beginning of your mapscript:

```lua
AngusAI_Init()
```

2.Initialize an AI

```lua
AngusAI_Add(5, "Der Wingl", "P4_StartPos", NPC_COLOR, 200, 450, 3, 1000000)
```

PlayerId: 5
Name: "Der Wingl"
HQScriptName: "P4_StartPos"
Color: NPC_COLOR (Gold)
MinUpgradeTime: 200 -- minimal time to improve the AI's strength
MaxUpgradeTime: 450 -- maximal time to improve the AI's strength
MinUpgradeTime: 3   -- the AI's Army size (0 - 3) (None - Big)
MaxAIRange: 1000000 -- the range of the AI's enemy detection