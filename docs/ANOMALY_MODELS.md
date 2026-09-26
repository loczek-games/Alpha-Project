# Anomaly models

Every anomaly body comes from `ServerScriptService/Anomalies/Appearance.lua`,
resolved in this order:

1. **Override** – a Model you put in `ServerStorage/AnomalyModels/<Name>`
2. **Catalog** – the bundle / asset id from `Appearance.Library`, loaded with
   `AssetService` at server start
3. **Procedural** – the built-in rig (`Anomalies/Rig.lua`), so a spawn never fails

The output says which source was used, e.g. `[AnomalyModels] SmilingEntity: catalog bundle 218626722487791`.

| Name | Catalog source | Procedural style |
|---|---|---|
| AbnormalTitan | bundle 130669835003582 | Titan |
| SmilingEntity | bundle 218626722487791 | Smiler |
| PossessedEntity | bundle 946396 | Possessed |
| SlackerEntity | bundle 239940076376674 | Slacker |
| RatthewAnomaly | asset 77243079770705 | Rat |
| CeilingCrawler | – | Spider (8 legs, human face) |
| Mannequin, StoreDummy, Faceless, Shadow, Employee, Listener | – | built in |

## Manual step (only if the catalog load fails)

`AssetService`/`InsertService` can only load items the game's owner is allowed to
use. If the output reports a catalog failure:

1. In Studio, insert the bundle/model from the Toolbox or Avatar Shop.
2. Rename it to the name above and drop it into `ServerStorage/AnomalyModels/<Name>`
   (replace the empty placeholder folder).
3. It must have a `Humanoid` and a `HumanoidRootPart` (R15). Anchoring,
   collision groups and animation are handled by the game.

The model is then used for that anomaly everywhere, including its jumpscare.
