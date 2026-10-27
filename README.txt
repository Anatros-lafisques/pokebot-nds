PokéBot NDS — roamer fix (updated)
==================================

Fixes the Platinum roamers crash, and stops a non-shiny Cresselia
from being released into the world.

A non-shiny is always soft-reset the frame it is generated.
IV totals no longer count as a reason to keep it.
Only a shiny of the Pokemon you are hunting stops the bot.

Install
-------
Close the Lua script window in DeSmuME, then replace these files
in your pokebot-nds folder:

  lua/methods/gen_iv.lua
  lua/methods/pt.lua
  lua/modules/pokemon.lua

If the one that got away is still only in this session and you have
not saved since, reset the emulator. You will be back in front of her.
If you saved after she flew, load the save from before that.

Then set TID/SID override, reload pokebot-nds.lua, and start Roamers.
