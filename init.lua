-- mod-version:3
local core = require "core"
local keymap = require "core.keymap"
local command = require "core.command"

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
  local index = mt.__index
  mt.__index = function(_, key)
    if fallback(key) then
      return originalkeymap.map[key]
    end
    return index(_, key)
  end
end

local reset

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

local function makemode(modekey, modemap, mt, wrapper)
  local mode = {}
  local keys = {}
  for key, actions in pairs(modemap) do
    if key == "fallback" then
      setupfallback(mt, actions)
    elseif key == "onenter" then
      mode.onenter = actions
    else
      keys[key] = wrapper(actions)
    end
  end
  local map, reversemap = createmaps(keys, mt)
  mode.map = map
  mode.reversemap = reversemap
  modes[modekey] = mode
end

local mapmt = {
  __index = function(_, key)
    core.log(key .. " not mapped")
    return { nop }
  end
}

local function idwrap(actions) return actions end

function modal.map(modemaps)
  for name, modemap in pairs(modemaps) do
    makemode(name, modemap, mapmt, idwrap)
  end
end

local function setmode(modekey)
  local mode = modes[modekey]
  keymap.map = mode.map
  keymap.reverse_map = mode.reversemap
  if type(mode.onenter) == "function" then
    mode.onenter()
  end
end

local function wrap(actions)
  local wrapped = {}
  if type(actions) ~= "table" then
    actions = { actions }
  end
  for _, action in ipairs(actions) do
    local newaction = function(...)
      local performed = false
      if type(action) == "string" then
        performed = command.perform(action, ...)
      elseif type(action) == "function" then
        performed = action(...)
      end
      reset()
      return performed
    end
    table.insert(wrapped, newaction)
  end
  table.insert(wrapped, reset)
  return wrapped
end

local submapmt = {
  __index = function()
    return { reset }
  end
}

function modal.submap(map)
  local function activatesubmode()
    setmode(activatesubmode)
  end

  makemode(activatesubmode, map, submapmt, wrap)

  return activatesubmode
end

function modal.mode(modename)
  return function()
    setmode(modename)
  end
end

function modal.activate(modename)
  reset = modal.mode(modename)
  viewmodifier.activate(reset, restore)
end

return modal

