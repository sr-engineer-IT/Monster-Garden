--!strict
-- Per-model fixes for 3D models in assets/models (see Resources/Model-Names.md).
-- Turn: degrees to spin the model if its front (door, face) points the wrong way.
--       Try 90, 180 or -90. Scale: make it bigger (1.2) or smaller (0.8) than the default fit.
-- Example: Cottage = { Turn = 180, Scale = 1.1 },
-- Gates (Building_wood_fence, Building_reinforced_fence) turn themselves automatically so their
-- long side runs along the fence, so they need no entry here.

return {
	Bench = { Turn = 90 }, -- benches faced sideways around the fountain; now they face the water
} :: { [string]: { Turn: number?, Scale: number? } }
