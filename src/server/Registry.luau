--!strict
-- Service registry, filled by Main.server before any Init() runs.
-- Services use it inside functions (never at load time) to call each other without require cycles:
--   local S = require(script.Parent.Parent.Registry)
--   S.ProgressionService.AddXP(player, 10)

return {} :: { [string]: any }
