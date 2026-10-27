-----------------------------------------------------------------------------
-- General bot methods for gen 4 games (DPPt, HGSS)
-- Author: wyanido, storyzealot, FalinMor_
-- Homepage: https://github.com/Falin-Mor/pokebot-nds
-----------------------------------------------------------------------------
local printed_d_not_ready  = false
local printed_d_not_found  = false
local printed_d_found      = false

local d_species_addr = nil
local d_status_addr  = nil

local function diamond_scan_species_window()

    if d_species_addr then
        return d_species_addr, d_status_addr
    end

    -- Ensure foe struct is populated
    local mon = foe and foe[1]
    if not mon or mon.species == 0 then
        if not printed_d_not_ready then
            print_debug("[DP] Species scan: struct not ready yet")
            printed_d_not_ready = true
        end
        return nil, nil
    end

    local target_species = mon.species

    -- Diamond window (stable)
    local SCAN_START    = 0x022B5800
    local SCAN_END      = 0x022B5A00
    local STATUS_OFFSET = 0x5A86

    -- Scan for species ID
    for addr = SCAN_START, SCAN_END, 2 do
        if mword(addr) == target_species then
            d_species_addr = addr
            d_status_addr  = addr + STATUS_OFFSET

            if not printed_d_found then
                print_debug(string.format(
                    "[DP] Species found: %d @ %08X → status @ %08X",
                    target_species, d_species_addr, d_status_addr
                ))
                printed_d_found = true
            end

            return d_species_addr, d_status_addr
        end
    end

    if not printed_d_not_found then
        print_debug("[DP] Species scan: not in window yet.")
        printed_d_not_found = true
    end

    return nil, nil
end
	
function update_pointers()
    local anchor = mdword(0x21C489C + _ROM.offset)
    local foe_anchor = mdword(anchor + 0x226FE)
    local bag_page_anchor = mdword(anchor + 0x560EE)
    local roamer_anchor = mdword(anchor + 0x4272A)

	local species_addr, status_addr = diamond_scan_species_window()

	local hp_addr  = nil
	local max_addr = nil

	if species_addr then
		hp_addr  = species_addr + 0x4C
		max_addr = species_addr + 0x50
	end
		
	if _ROM.version == "D" then
		fishing_exclamation_popup = 0x02291E57
	elseif _ROM.version == "P" then
		fishing_exclamation_popup = 0x02291E1F
	else
		fishing_exclamation_popup = 0x022A1AAF
	end

    -- Diamond/Pearl general save block sits 0x86 bytes before this anchor
    -- (party data is anchor+0x12, save party offset is 0x98).
    -- Roamers are the 0x14-byte Roamer4 structs at save offset 0x73A0:
    -- slot 0 Mesprit, slot 1 Cresselia, slot 2 unused.
    local roamer_slots = nil
    if anchor > 0x02000000 then
        local roamer_base = (anchor - 0x86) + 0x73A0
        roamer_slots = {
            roamer_base,
            roamer_base + 0x14,
            roamer_base + 0x28,
        }
    end
	
    pointers = {
        start_value = 0x21066D4, -- 0 until save has been loaded
        -- items_pocket      = anchor + 0x59E,
        -- key_items_pocket  = anchor + 0x832,
        -- tms_hms_pocket    = anchor + 0x8FA,
        -- medicine_pocket   = anchor + 0xABA,
        -- berries_pocket    = anchor + 0xB5A,
        poke_balls_pocket = anchor + 0xC5A,
        
        party_count = anchor + 0xE,
        party_data  = anchor + 0x12,

        foe_count   = foe_anchor - 0x2B74,
        current_foe = foe_anchor - 0x2B70,
		foe_species = species_addr,
		foe_status  = status_addr,
		currentHP   = hp_addr,
		maxHP       = max_addr,
		
        map_header  = anchor + 0x11B2,
        menu_option = 0x21CDF22 + _ROM.offset,
        trainer_x   = 0x21CEF70 + _ROM.offset,
        trainer_y   = 0x21CEF74 + _ROM.offset,
        trainer_z   = 0x21CEF78 + _ROM.offset,
        facing      = anchor + 0x247C6,

        bike_gear = anchor + 0x123E,
        bike      = anchor + 0x1242,

        daycare_egg = anchor + 0x156E,

        selected_starter = anchor + 0x427A6,
        starters_ready   = anchor + 0x4282A,
        
        battle_bag_page        = bag_page_anchor + 0x4E,
        battle_menu_state      = anchor + 0x455A6,
        battle_menu_state2 = anchor + 0xED6A6,
        battle_indicator       = 0x21A1B2A + _ROM.offset,
		
		fishing_exclamation_popup = fishing_exclamation_popup,
		
        trainer_name = anchor - 0x22,
        trainer_id   = anchor - 0x12,

        save_indicator = 0x21C491F + _ROM.offset,
        
        roamer = roamer_anchor + 0x20,
        roamer_slots = roamer_slots,
    }
end

function foe_has_status()
    return mbyte(pointers.foe_status) ~= 0
end

--- Waits a random duration after a reset to decrease the odds of hitting duplicate seeds
function randomise_reset()
    wait_frames(200) -- White screen on startup

    local delay = math.random(100, 500)

    print_debug("Delaying " .. delay .. " frames...")
    wait_frames(delay)

    while not game_state.in_game do
        press_sequence("Start", 20, "A", math.random(8, 28))
    end
end

--- Opens the menu and selects the specified option
-- @param menu Name of the menu to open
function open_menu(menu)
    local option = {
        Pokedex = 1,
        Pokemon = 2,
        Bag = 4,
        Trainer = 5,
        Save = 7,
        Options = 8,
        Exit = 10
    }

    press_sequence("X", 8)
    
    -- Scroll up or down based on which navigation is shorter (doesn't acknowledge that the menu wraps around)
    local direction = option[menu] > mbyte(pointers.menu_option) and "Down" or "Up"
    while mbyte(pointers.menu_option) ~= option[menu] do
        press_sequence(direction, 8)
    end

    press_sequence("A", 90)
end

--- Returns an array of all Poke Balls within the Poke Balls bag pocket
function get_usable_balls()
    process_frame()      -- updates game_state
	update_pointers()    -- builds pointer table
	local balls = {}
    local slot = 0

    for i = pointers.poke_balls_pocket, pointers.poke_balls_pocket + 0x3A, 4 do
        local count = mword(i + 2)

        if count > 0 then
            local id = mword(i)
            local item_name = _ITEM[id + 1]

            balls[string.lower(item_name)] = slot + 1
        end

        slot = slot + 1
    end

    return balls
end

--- Navigates to the Solaceon Town daycare and releases all hatched Pokemon in the party
function release_hatched_duds()
    local function release()
        press_sequence("A", 5, "Up", 5, "Up", 5, "A", 5, "Up", 5, "A", 120, "A", 60, "A", 10)
    end

    clear_all_inputs()

    move_to({z=646})
    move_to({x=553})
    
    -- Enter door
    hold_button("Up")
    wait_frames(60)
    release_button("Up")
    wait_frames(120)
    
    hold_button("B")
    move_to({z=8})
    move_to({x=4})
    move_to({z=4})
    clear_all_inputs()

    -- Navigate to MOVE POKEMON
    wait_frames(5)
    press_sequence("A", 90, "A", 60, "A", 60, "A", 20, "Down", 10, "Down", 10, "A", 150)

    -- Navigate to PARTY POKEMON
    press_sequence("Up", 20, "Up", 20, "A", 60)
    press_sequence("Up", 20, "Up", 20)

    -- Release Lv 1 Pokemon from back to front to accomodate for positions shifting
    if pokemon.is_hatched_dud(party[6]) then release() end
    press_sequence("Left", 10)
    if pokemon.is_hatched_dud(party[5]) then release() end
    press_sequence("Up", 10, "Right", 10)
    if pokemon.is_hatched_dud(party[4]) then release() end
    press_sequence("Left", 10)
    if pokemon.is_hatched_dud(party[3]) then release() end
    press_sequence("Up", 10, "Right", 10)
    if pokemon.is_hatched_dud(party[2]) then release() end

    -- Close PC
    press_sequence("B", 60, "B", 20, "B", 160, "B", 60, "B", 20)

    -- Exit Daycare
    hold_button("B")
    move_to({z=8})
    move_to({x=9})
    move_to({z=11})
    wait_frames(60)
    clear_all_inputs()
    
    -- Return to long vertical path
    press_sequence(110, "Y")
    move_to({x=562})
end

--- Proceeds until the egg hatch animation finishes
function hatch_egg(slot)
    press_sequence(30, "B", 30)
            
    -- Mon data changes again once animation finishes
    local checksum = party[slot].checksum
    while party[slot].checksum == checksum do
        press_sequence("B", 5)
    end
end

--- Converts bytes into readable text using the game's respective encoding method.
-- @param input Table of bytes or memory address to read from
-- @param pointer Offset into the byte table if provided
function read_string(input, pointer)
    local char_table = {
        "　", "ぁ", "あ", "ぃ", "い", "ぅ", "う", "ぇ", "え", "ぉ", "お", "か", "が", "き", "ぎ",
        "く", "ぐ", "け", "げ", "こ", "ご", "さ", "ざ", "し", "じ", "す", "ず", "せ", "ぜ", "そ", "ぞ",
        "た", "だ", "ち", "ぢ", "っ", "つ", "づ", "て", "で", "と", "ど", "な", "に", "ぬ", "ね", "の",
        "は", "ば", "ぱ", "ひ", "び", "ぴ", "ふ", "ぶ", "ぷ", "へ", "べ", "ぺ", "ほ", "ぼ", "ぽ", "ま",
        "み", "む", "め", "も", "ゃ", "や", "ゅ", "ゆ", "ょ", "よ", "ら", "り", "る", "れ", "ろ", "わ",
        "を", "ん", "ァ", "ア", "ィ", "イ", "ゥ", "ウ", "ェ", "エ", "ォ", "オ", "カ", "ガ", "キ", "ギ",
        "ク", "グ", "ケ", "ゲ", "コ", "ゴ", "サ", "ザ", "シ", "ジ", "ス", "ズ", "セ", "ゼ", "ソ", "ゾ",
        "タ", "ダ", "チ", "ヂ", "ッ", "ツ", "ヅ", "テ", "デ", "ト", "ド", "ナ", "ニ", "ヌ", "ネ", "ノ",
        "ハ", "バ", "パ", "ヒ", "ビ", "ピ", "フ", "ブ", "プ", "ヘ", "ベ", "ペ", "ホ", "ボ", "ポ", "マ",
        "ミ", "ム", "メ", "モ", "ャ", "ヤ", "ュ", "ユ", "ョ", "ヨ", "ラ", "リ", "ル", "レ", "ロ", "ワ",
        "ヲ", "ン", "０", "１", "２", "３", "４", "５", "６", "７", "８", "９", "Ａ", "Ｂ", "Ｃ", "Ｄ",
        "Ｅ", "Ｆ", "Ｇ", "Ｈ", "Ｉ", "Ｊ", "Ｋ", "Ｌ", "Ｍ", "Ｎ", "Ｏ", "Ｐ", "Ｑ", "Ｒ", "Ｓ", "Ｔ",
        "Ｕ", "Ｖ", "Ｗ", "Ｘ", "Ｙ", "Ｚ", "ａ", "ｂ", "ｃ", "ｄ", "ｅ", "ｆ", "ｇ", "ｈ", "ｉ", "ｊ",
        "ｋ", "ｌ", "ｍ", "ｎ", "ｏ", "ｐ", "ｑ", "ｒ", "ｓ", "ｔ", "ｕ", "ｖ", "ｗ", "ｘ", "ｙ", "ｚ",
        "",   "！", "？", "、", "。", "…", "・", "／", "「", "」", "『", "』", "（", "）", "♂", "♀",
        "＋", "ー", "×", "÷", "＝", "～", "：", "；", "．", "，", "♠", "♣", "♥", "♦", "★", "◎",
        "○", "□", "△", "◇", "＠", "♪", "％", "☀", "☁", "☂", "☃", "😑", "☺", "☹", "😠", "⤴︎",
        "⤵︎", "💤", "円", "💰", "🗝️", "💿", "✉️", "💊", "🍓", "◓", "💥", "←", "↑", "↓", "→", "►",
        "＆", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E",
        "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U",
        "V", "W", "X", "Y", "Z", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k",
        "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "À",
        "Á", "Â", "Ã", "Ä", "Å", "Æ", "Ç", "È", "É", "Ê", "Ë", "Ì", "Í", "Î", "Ï", "Ð",
        "Ñ", "Ò", "Ó", "Ô", "Õ", "Ö", "×", "Ø", "Ù", "Ú", "Û", "Ü", "Ý", "Þ", "ß", "à",
        "á", "â", "ã", "ä", "å", "æ", "ç", "è", "é", "ê", "ë", "ì", "í", "î", "ï", "ð",
        "ñ", "ò", "ó", "ô", "õ", "ö", "÷", "ø", "ù", "ú", "û", "ü", "ý", "þ", "ÿ", "Œ",
        "œ", "Ş", "ş", "ª", "º", "er", "re", "r", "₽", "¡", "¿", "!", "?", ",", ".", "…",
        "･", "/", "‘", "’", "“", "”", "„", "«", "»", "(", ")", "♂", "♀", "+", "-", "*",
        "#", "=", "&", "~", ":", ";", "♠", "♣", "♥", "♦", "★", "◎", "○", "□", "△", "◇",
        "@", "♪", "%", "☀", "☁", "☂", "☃", "😑", "☺", "☹", "😠", "⤴︎", "⤵︎", "💤", " ", "e",
        "PK", "MN", " ", " ", " ", "", " ", " ", "°", "_", "＿", "․", "‥",
    }
    local text = ""

    if type(input) == "table" then
        -- Read data from an inputted table of bytes
        for i = pointer + 1, #input, 2 do
            local value = input[i] + bit.lshift(input[i + 1], 8)

            if value == 0xFFFF or value == 0x0000 then -- Null terminator
                break
            end

            text = text .. (char_table[value] or "?")
        end
    else
        -- Read data from an inputted address
        for i = input, input + 32, 2 do
            local value = mword(i)

            if value == 0xFFFF or value == 0x0000 then -- Null terminator
                break
            end

            text = text .. (char_table[value] or "?")
        end
    end

    return text
end

--- Returns the current stage of the battle as a simple string
function get_battle_state()
    if not game_state.in_battle then
        return nil
    end

	local s = mbyte(pointers.battle_menu_state2)
	if s == 0x2F or s == 0x2E then
		return "New Move"
	end
    
    local state = mbyte(pointers.battle_menu_state)

    if state == 0x1 then
        return "Menu"
    elseif state == 0x3 then
        return "Fight"
    elseif state == 0x7 then
        return "Bag"
    elseif state == 0x9 then
        return "Pokemon"
    end

    return nil
end

--- Picks the specified starter Pokemon each reset until it's a target
function mode_starters()
    cycle_starter_choice()
    
    -- Diamond and Pearl need to skip through a cutscene before the briefcase
    local platinum = _ROM.version == "PL"

    if not platinum then 
        hold_button("Up")

        while game_state.map_name ~= "Lake Verity" do
            progress_text()
        end
        
        release_button("Up")
    end
    
    print("Waiting to open briefcase...")
    
    -- Skip until the starter can be selected, which
    -- is known when the lower 4 bits of the byte at
    -- the starters pointer equals the ready value
    local ready_value = platinum and 0xD or 0x5

    while bit.band(bit.band(mbyte(pointers.starters_ready), 15), ready_value) ~= ready_value do
        progress_text()
    end

    print("Selecting starter...")

    press_sequence("Left", 10)
	
    while mbyte(pointers.selected_starter) < starter do
        press_sequence("Right", 5)
    end

	press_button("A")	

    -- Wait until starter is added to party
    while #party == 0 do
        progress_text()
    end

    -- Log encounter, stopping if necessary
    local mon = party[1]
    local is_target = pokemon.log_encounter(mon)

    if is_target then
        abort(mon.name .. " is a target!")
    else
        print(mon.name .. " was not a target, resetting...")
        soft_reset()
    end
end

local printed_SZ_warning = false

--- Encounters wild Pokemon until a target is found. Can battle and catch
function mode_random_encounters()
	local all_dirs = {"Up", "Down", "Left", "Right"}

	if game_state.map_name == "Safari Zone" and not printed_SZ_warning then
		print("Safari Zone Detected. If auto-catch is enabled,")
		print("this bot will assume you started with 30 balls.")
		print("This will stop when bot uses more than 15 in one run")
		print("and save upon exit. This can be adjusted in global.lua.")
		print("Use at less than 15 at your own risk.")
		printed_SZ_warning = true
	end	
	
	local function spin()
		-- Read facing safely
		local facing_value = mbyte(pointers.facing)      -- 0=Up,1=Down,2=Left,3=Right
		local facing_dir = all_dirs[facing_value + 1]    -- Convert to string

		while not game_state.in_battle do
			-- Build a 3‑direction spin that excludes the facing direction
			for _, dir in ipairs(all_dirs) do
				if dir ~= facing_dir then
					press_sequence(dir, 3)
				end
			end
		end
	end

    local function run_back_and_forth()
        local dir1, dir2, start_face
        
        if config.move_direction == "horizontal" then
            dir1 = "Left"
            dir2 = "Right"
            start_face = 0
        else
            dir1 = "Up"
            dir2 = "Down"
            start_face = 2
        end

        if mbyte(pointers.facing) ~= start_face then
            press_sequence(dir2, 8)
        end

        hold_button("B")
        
        while not game_state.in_battle do
            hold_button(dir1)
            wait_frames(7)
			release_button(dir1)
            hold_button(dir2)
            wait_frames(7)
			release_button(dir2)
        end

        release_button("B")
    end

    check_party_status()
    
    print("Attempting to start a battle...")
    wait_frames(30)

    if config.move_direction == "spin" then
        spin()
    else
        run_back_and_forth()
    end

    process_wild_encounter()
end

--- Hunts for targets by hatching eggs
-- Bikes through Solaceon Town until the party is full of hatched eggs,
-- then frees up party space at the PC if no targets were hatched
function mode_daycare_eggs()
    local function mount_bike()
        if mbyte(pointers.bike) ~= 1 then press_sequence("Y", 5) end
        if mbyte(pointers.bike_gear) ~= 1 then press_button("B") end
    end
    
    local function check_and_collect_egg()
        -- Don't bother with additional eggs if party is full
        if #party == 6 or mdword(pointers.daycare_egg) == 0 then
            return
        end

        print("That's an egg!")

        move_to({z=648}, check_hatching_eggs)
        move_to({x=556}, check_hatching_eggs)
        clear_all_inputs()

        local party_count = #party
        while #party == party_count do
            progress_text()
        end

        -- Return to long vertical path 
        move_to({x=562}, check_hatching_eggs)
    end

    -- Initialise party state for future reference
    process_frame()
    party_egg_states = get_party_egg_states()

    mount_bike()
    move_to({x=562}, check_hatching_eggs)
    
    while true do
        move_to({z=630}, check_hatching_eggs)
        check_and_collect_egg()
        move_to({z=675}, check_hatching_eggs)
        check_and_collect_egg()
    end
end

-- Gen 4 roamers are not encrypted party Pokemon. They are 0x14-byte records:
--   0x00 location u32
--   0x04 ivs u32 (HP/Atk/Def/Spe/SpA/SpD, 5 bits each)
--   0x08 personality u32
--   0x0C species u16
--   0x0E current HP u16
--   0x10 level u8
--   0x11 status u8
--   0x12 active u8
-- TID/SID are not stored, so the override is what decides shininess.
local ROAMER_GENDER_RATIO = {
    [144] = 255, -- Articuno
    [145] = 255, -- Zapdos
    [146] = 255, -- Moltres
    [481] = 255, -- Mesprit
    [488] = 254, -- Cresselia
    [491] = 255, -- Darkrai
}

local ROAMER_ABILITY = {
    [144] = "Pressure",
    [145] = "Pressure",
    [146] = "Pressure",
    [481] = "Levitate",
    [488] = "Levitate",
    [491] = "Bad Dreams",
}

local function roamer_gender(species, pid)
    local ratio = ROAMER_GENDER_RATIO[species] or 255
    if ratio == 255 then return "Genderless" end
    if ratio == 254 then return "Female" end
    if ratio == 0 then return "Male" end
    if bit.band(pid, 0xFF) < ratio then return "Female" end
    return "Male"
end

local function read_roamer_slot(addr)
    if not addr or addr < 0x02000000 then
        return nil
    end

    local active = mbyte(addr + 0x12)
    local species = mword(addr + 0x0C)
    local pid = mdword(addr + 0x08)
    local level = mbyte(addr + 0x10)

    if active ~= 1 or species == 0 or species > 493 then
        return nil
    end
    if pid == 0 or pid == 0xFFFFFFFF then
        return nil
    end
    if level == 0 or level > 100 then
        return nil
    end

    return {
        addr = addr,
        species = species,
        pid = pid,
        iv32 = mdword(addr + 0x04),
        level = level,
        hp = mword(addr + 0x0E),
    }
end

local function scan_roamer_slots()
    local found = {}
    local slots = pointers.roamer_slots
    if not slots then
        return found
    end

    for _, addr in ipairs(slots) do
        local slot = read_roamer_slot(addr)
        if slot then
            table.insert(found, slot)
        end
    end

    return found
end

local function wanted_roamer_species()
    local traits = config.target_traits or {}
    local wanted = {}
    local any_species = true

    local function add_name(name)
        if type(name) ~= "string" then
            return
        end

        for i = 2, #_DEX do
            local entry = _DEX[i]
            if entry and entry[1] and string.lower(entry[1]) == string.lower(name) then
                wanted[i - 1] = true
                any_species = false
            end
        end
    end

    if type(traits.name) == "string" then
        add_name(traits.name)
    elseif type(traits.name) == "table" then
        for _, name in pairs(traits.name) do
            add_name(name)
        end
    end

    if type(traits.species) == "number" then
        wanted[traits.species] = true
        any_species = false
    elseif type(traits.species) == "table" then
        for _, species in pairs(traits.species) do
            if type(species) == "number" then
                wanted[species] = true
                any_species = false
            end
        end
    end

    return wanted, any_species
end

local function mon_from_roamer(slot, tid, sid)
    local iv = slot.iv32
    local mon = {}
    local dex_entry = _DEX[slot.species + 1]

    mon.species = slot.species
    mon.pid = string.format("%08X", slot.pid)
    mon.level = slot.level
    mon.hpIV = bit.band(iv, 0x1F)
    mon.attackIV = bit.band(bit.rshift(iv, 5), 0x1F)
    mon.defenseIV = bit.band(bit.rshift(iv, 10), 0x1F)
    mon.speedIV = bit.band(bit.rshift(iv, 15), 0x1F)
    mon.spAttackIV = bit.band(bit.rshift(iv, 20), 0x1F)
    mon.spDefenseIV = bit.band(bit.rshift(iv, 25), 0x1F)
    mon.ivSum = mon.hpIV + mon.attackIV + mon.defenseIV + mon.spAttackIV + mon.spDefenseIV + mon.speedIV
    mon.perfectIVs = 0
    if mon.hpIV == 31 then mon.perfectIVs = mon.perfectIVs + 1 end
    if mon.attackIV == 31 then mon.perfectIVs = mon.perfectIVs + 1 end
    if mon.defenseIV == 31 then mon.perfectIVs = mon.perfectIVs + 1 end
    if mon.spAttackIV == 31 then mon.perfectIVs = mon.perfectIVs + 1 end
    if mon.spDefenseIV == 31 then mon.perfectIVs = mon.perfectIVs + 1 end
    if mon.speedIV == 31 then mon.perfectIVs = mon.perfectIVs + 1 end

    mon.nature = _NATURE[(slot.pid % 25) + 1] or "Unknown"
    mon.gender = roamer_gender(slot.species, slot.pid)
    mon.ability = ROAMER_ABILITY[slot.species] or "Unknown"
    mon.heldItem = "none"
    mon.isEgg = false
    mon.altForm = 0
    mon.name = (dex_entry and dex_entry[1]) or string.format("Species %d", slot.species)
    mon.type = (dex_entry and dex_entry[2]) or {}
    mon.nickname = mon.name
    mon.otID = tid
    mon.otSID = sid
    mon.checksum = 0
    mon.moves = {}
    mon.raw = {}

    local low = bit.band(slot.pid, 0xFFFF)
    local high = bit.band(bit.rshift(slot.pid, 16), 0xFFFF)
    mon.shinyValue = bit.bxor(bit.bxor(bit.bxor(tid, sid), high), low)
    mon.shiny = mon.shinyValue < 8

    local hpTypeList = {"fighting", "flying", "poison", "ground", "rock", "bug", "ghost", "steel", "fire", "water",
                        "grass", "electric", "psychic", "ice", "dragon", "dark"}
    local lsb = (mon.hpIV % 2) + (mon.attackIV % 2) * 2 + (mon.defenseIV % 2) * 4 + (mon.speedIV % 2) * 8 +
                    (mon.spAttackIV % 2) * 16 + (mon.spDefenseIV % 2) * 32
    local slsb = bit.rshift(bit.band(mon.hpIV, 2), 1) + bit.rshift(bit.band(mon.attackIV, 2), 1) * 2 +
                     bit.rshift(bit.band(mon.defenseIV, 2), 1) * 4 + bit.rshift(bit.band(mon.speedIV, 2), 1) * 8 +
                     bit.rshift(bit.band(mon.spAttackIV, 2), 1) * 16 + bit.rshift(bit.band(mon.spDefenseIV, 2), 1) * 32
    mon.hpType = hpTypeList[math.floor((lsb * 15) / 63) + 1]
    mon.hpPower = math.floor((slsb * 40) / 63) + 30

    return mon
end

local function slot_key(slot)
    return string.format("%d:%08X", slot.species, slot.pid)
end

-- Remembers PIDs already judged this session so a save made AFTER the
-- roamer flew away doesn't soft-reset the same Pokemon forever.
roamer_seen_pids = roamer_seen_pids or {}

local function should_keep_roamer(mon, wanted, any_species)
    -- A non-shiny must never be kept. An IV total, nature, or the default
    -- ivSum rule used to count as a target and skip the reset, which is how
    -- a normal Cresselia could finish the cutscene and start roaming.
    if not mon.shiny then
        return false
    end

    if not any_species and not wanted[mon.species] then
        return false
    end

    if config.always_catch_shinies or config.always_catch_shiny_male_genderless then
        return true
    end

    return pokemon.matches_ruleset(mon, config.target_traits)
end

local function judge_roamers(slots, tid, sid, wanted, any_species, from_baseline)
    for _, slot in ipairs(slots) do
        local key = slot_key(slot)
        local name = (_DEX[slot.species + 1] and _DEX[slot.species + 1][1]) or "Roamer"

        if roamer_seen_pids[key] then
            abort(name .. " is already roaming on this save, so resetting loads the same Pokemon. Load the save from before it flew away, then start the hunt again.")
        end

        local mon = mon_from_roamer(slot, tid, sid)
        print(string.format(
            "%s | PID %s | SV %d | Shiny %s | %s %s | Lv%d | IVs %d/%d/%d/%d/%d/%d",
            mon.name, mon.pid, mon.shinyValue, tostring(mon.shiny),
            mon.nature, mon.gender, mon.level,
            mon.hpIV, mon.attackIV, mon.defenseIV, mon.spAttackIV, mon.spDefenseIV, mon.speedIV
        ))

        clear_all_inputs()

        if not should_keep_roamer(mon, wanted, any_species) then
            if from_baseline then
                abort(name .. " is already roaming and is not shiny. Load the save from before it flew away, then start the hunt again.")
            end

            -- Log first, but never let a dashboard error skip the reset.
            pcall(pokemon.log_encounter, mon)
            print("Not shiny, resetting before it can roam.")
            soft_reset()
            return
        end

        roamer_seen_pids[key] = true
        pcall(pokemon.log_encounter, mon)
        abort(mon.name .. " is a shiny target!")
    end
end

local function mode_roamers_from_slots(tid, sid)
    local wanted, any_species = wanted_roamer_species()
    local announced = false

    while not game_state.in_game or not pointers.roamer_slots do
        wait_frames(1)
    end

    -- Let the save block finish loading before the baseline snapshot.
    wait_frames(30)

    local baseline = {}
    local already = {}
    local present = {}
    for _, slot in ipairs(scan_roamer_slots()) do
        baseline[slot_key(slot)] = true
        present[slot.species] = true
        if not any_species and wanted[slot.species] then
            table.insert(already, slot)
        end
    end

    -- If every targeted species is already roaming, this save was made after
    -- they flew away. Judge those records now. If one is still missing, ignore
    -- roamers that were already active and wait for the new one.
    local waiting_on_new = any_species
    if not any_species then
        for species, _ in pairs(wanted) do
            if not present[species] then
                waiting_on_new = true
                break
            end
        end
    end

    if not waiting_on_new and #already > 0 then
        judge_roamers(already, tid, sid, wanted, any_species, true)
        return
    end

    local a_cooldown = 0
    while true do
        -- Read before touching A. The confirming press is what makes her roam,
        -- so a non-shiny has to be reset on the frame it appears.
        local fresh = {}
        for _, slot in ipairs(scan_roamer_slots()) do
            if not baseline[slot_key(slot)] and (any_species or wanted[slot.species]) then
                table.insert(fresh, slot)
            end
        end

        if #fresh > 0 then
            clear_all_inputs()
            judge_roamers(fresh, tid, sid, wanted, any_species, false)
            return
        end

        if not announced then
            if any_species then
                print("Waiting for a roamer to generate...")
            else
                print("Waiting for the target roamer to generate...")
            end
            announced = true
        end

        if a_cooldown == 0 then
            press_button_async("A")
            a_cooldown = math.random(4, 12)
        else
            a_cooldown = a_cooldown - 1
        end

        wait_frames(1)
    end
end

function mode_roamers()
    local tid
    local sid

    if not config.ot_override then
        abort("You must set your TID/SID override before you can start.")
    end

    tid = tonumber(config.tid_override)
    sid = tonumber(config.sid_override)
    if not tid or not sid or tid < 0 or sid < 0 or tid > 65535 or sid > 65535 then
        abort("TID/SID override must be whole numbers from 0 to 65535.")
    end
    tid = bit.band(tid, 0xFFFF)
    sid = bit.band(sid, 0xFFFF)

    print(string.format("Roamer hunt using TID %d / SID %d", tid, sid))

    -- Diamond, Pearl and Platinum keep roamers in the compact save struct.
    -- Reading that as a party Pokemon is what crashed pokemon.lua:294.
    if _ROM.version == "D" or _ROM.version == "P" or _ROM.version == "PL" then
        mode_roamers_from_slots(tid, sid)
        return
    end

    local data
    local a_cooldown = 0
    local is_unencrypted = _ROM.version ~= "PL"

    while not data do
        data = pokemon.read_data(pointers.roamer, is_unencrypted)

        if a_cooldown == 0 then
            press_button_async("A")
            a_cooldown = math.random(5, 20)
        else
            a_cooldown = a_cooldown - 1
        end

        wait_frames(1)
    end

    local mon = pokemon.parse_data(data, true)
    if not mon or not mon.name then
        print_warn("Roamer data could not be parsed, resetting...")
        soft_reset()
        return
    end

    mon.otID = tid
    mon.otSID = sid

    local is_target = pokemon.log_encounter(mon)

    if mon.name == "Unown" then
        abort("Please clear the journal and then save to resume.")
    end

    if is_target then
        abort(mon.name .. " is a target!")
    else
        soft_reset()
    end
end
