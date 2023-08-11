local core = require "core"
local docview = require "core.docview"
local commandview = require "core.commandview"

local activated = false

-- TODO per view map
local function activate(setfn, resetfn)
  if not activated then
    activated = true
    local set_active_view = core.set_active_view
    function core.set_active_view(view)
      set_active_view(view)
      if view:is(docview) then
        setfn()
      elseif view:is(commandview) then
        resetfn(true)
      else
        resetfn()
      end
    end
  else
    if core.active_view:is(docview) then
      setfn()
    end
  end
end

return {
  activate = activate,
}

