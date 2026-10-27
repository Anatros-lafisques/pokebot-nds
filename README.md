# PokéBot NDS
<img src='https://i.imgur.com/lHaYC4z.png' width='600px'>

i take no ownership of this program credit is due to those before me (Wyanido the original creator, Falin-Mor the previous maintainer) i merely used an llm to fix the issue with hunting the roamer Cresselia and i just wanted to share it with those who wish to have an easier time to hunt her. i will attempt to fix any issues that may appear from the changes i have made feel free to @me in the discord chat. if you find an error providing a screen shot of the error will help tons.


This repository is dedicated to creating a multi-purpose automated tool for the mainline DS Pokémon games.

## Getting Started
#### Prerequisites
You'll need to install [node.js](https://nodejs.org/en), and have a recent version of [DeSmuME](https://github.com/TASEmulators/desmume/releases/latest) in order to use this tool. 

#### Installation
**Recommended**: Install [Github Desktop](https://desktop.github.com/) and locally clone this repository to stay up to date with the latest versions of the bot.

Alternatively, download the repository as a .zip archive and extract it anywhere you like.

#### Setup
1. Start the dashboard with `start-dashboard.bat`, or run these commands inside the `dashboard/` folder:
    - `npm i`
    - `npm start`
2. Use the dashboard's Config tab to customise the bot behaviour for your current task. 
3. Open the Lua Console, and load `pokebot-nds.lua`. `Tools > Lua Scripting > New Lua Script Window`

NOTE: Bizhawk has MAJOR issues and is no longer supported.

The game will then be connected to the dashboard, which you can view info for on the Dashboard tab. The bot will immediately start acting according to your Config, and log any encounters to the dashboard.

## Bot Modes
|  						| DPPt | HGSS | BW | B2W2 | 
|--						| :-: | :-: | :-: | :-: |
| Starter resets 		| ✅ | ✅ | ✅ | ✅ |
| Random encounters		| ✅ | ✅ | ✅ | ✅ |
| Phenomenon encounters		|  |  | ✅ | ✅ |
| Gift resets 			| ✅ | ✅ | ✅ | ✅ |
| Static encounters 	| ✅ | ✅ | ✅ | ✅ |
| Fishing			   	| ✅ | ✅ | ✅ | ✅ |
| Egg hatching			| ✅ | ✅ | ✅ | ✅ |
| Headbutt Trees 		|  | ✅ |  |  |
| Thundurus/Tornadus dex resets 			|  |  | ✅ |  |
| Hidden Grottos 	|  |  |  | ✅ |

#### Additional Features
|  						| DPPt | HGSS | BW | B2W2 | 
|--						| :-: | :-: | :-: | :-: |
| Auto-catching			| ✅ | ✅ | ✅ | ✅ |
| Auto-battling			| ✅ | ✅ | ✅ | ✅ |
| Thief farming			| ✅ | ✅ | ✅ | ✅ |
| Pickup farming		| ✅ | ✅ | ✅ | ✅ |
| Voltorb Flip		|  | ✅ |  |  |

## Special Thanks

- The contributors of [BizHawk](https://github.com/TASEmulators/BizHawk) and [DeSmuME](https://github.com/TASEmulators/DeSmuME) for providing a basis to make this project possible
- [40 Cakes](https://github.com/40Cakes) for the [Gen III PokéBot](https://github.com/40Cakes/pokebot-gen3) that originally inspired this project
- [evandixon](https://projectpokemon.org/home/profile/183-evandixon/) for demystifying the [NDS Pokemon format](https://projectpokemon.org/home/docs/gen-5/bw-save-structure-r60)
- wyanido for the orginal bot.
