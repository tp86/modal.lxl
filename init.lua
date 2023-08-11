-- mod-version:3
local core = require "core"
local keymap = require "core.keymap"

local thismodule = (...)
local originalkeymap = require(thismodule ..  ".keymap")
local viewmodifier = require(thismodule .. ".view")

local modes = {}

local function nop() end

local function setupfallback(mt, fallbackkeys)
  local fallback
  if type(fallbackkeys) == "function" then
    fallback = fallbackkeys
  elseif type(fallbackkeys) == "table" then
    -- convert sequence of keys into lookup table
    local keys = {}
    for _, key in ipairs(fallbackkeys) do
      keys[key] = true
    end
    fallback = function(key)
      return keys[key]
    end
  end
  mt.__index = function(_, key)
    if fallback(key) then
      return originalkeymap.map[key]
    end
    core.log(key .. " not mapped")
    return { nop }
  end
end

local function restore(maponly)
  keymap.map = originalkeymap.map
  if not maponly then
    keymap.reverse_map = originalkeymap.reverse_map
  end
end

local function createmaps(keys, mt)
  keymap.map, keymap.reverse_map = {}, {}
  originalkeymap.add_direct(keys)
  local map, reverse_map = keymap.map, keymap.reverse_map
  restore()
  setmetatable(map, mt)
  return map, reverse_map
end

local modal = {}

function modal.map(modemaps)
  for name, modemap in pairs(modemaps) do
    local mode = {}
    local keys, mt = {}, {}
    for key, actions in pairs(modemap) do
      if key == "fallback" then
        setupfallback(mt, actions)
      elseif key == "onenter" then
        mode.onenter = actions
      else
        keys[key] = actions
      end
    end
    local map, reversemap = createmaps(keys, mt)
    mode.map = map
    mode.reversemap = reversemap
    modes[name] = mode
  end
end

function modal.mode(modename)
  return function()
    local mode = modes[modename]
    --core.log("activating mode %s", modename)
    keymap.map = mode.map
    keymap.reverse_map = mode.reversemap
    if type(mode.onenter) == "function" then
      mode.onenter()
    end
  end
end

function modal.activate(modename)
  local modefn = modal.mode(modename)
  viewmodifier.activate(modefn, restore)
  -- modefn()
  -- keymap.add = nop
  -- keymap.add_direct = nop
end

return modal

