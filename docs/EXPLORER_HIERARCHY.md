# Roblox Studio Explorer Hierarchy

Exact hierarchy of **CAUGHT ON CAMERA 📸**. Items marked *(runtime)* are created
by code when the server starts, so you do **not** create them by hand.

```
game
├── Workspace
│   ├── Map                                   Folder
│   │   └── DeadMall                          Folder   (filled at runtime by MapService if empty)
│   │       ├── Structure                     Folder   (runtime) floors, walls, ceilings, skylight
│   │       ├── Decor                         Folder   (runtime) fountain, benches, tables, shelves, cars...
│   │       ├── Fixtures                      Folder   (runtime) clocks, paintings, mirror, EXIT signs, arcade cabinets
│   │       ├── Lights                        Folder   (runtime) light panels tagged "MallLight"
│   │       ├── Zones                         Model    (runtime, Persistent streaming) 8 zone bounds parts
│   │       │   ├── MainHall / FoodCourt / ToyStore / Arcade
│   │       │   └── Cinema / Bathrooms / ParkingGarage / StorageHallway
│   │       ├── PlayerSpawns                  Folder   (runtime) where players enter the mall
│   │       ├── NPCWaypoints                  Folder   (runtime) walking lanes for shoppers
│   │       └── NPCs                          Folder   (runtime) ambient shoppers during a round
│   ├── AnomalySpawns                         Folder   (filled at runtime) marker parts: Kind + Zone attributes
│   ├── Lobby                                 Folder   (filled at runtime if empty)
│   │   ├── LobbySpawn ×4                     SpawnLocation (runtime)
│   │   ├── DarkRoomDoor                      Part + ProximityPrompt, tag "DarkRoomEntrance" (runtime)
│   │   └── DarkRoom                          Model (runtime, Persistent streaming)
│   │       ├── FrameCanvas ×10               Part, tag "DarkRoomFrame", attribute Index 1-10
│   │       ├── Nameplate                     Part, tag "DarkRoomNameplate"
│   │       └── ExitDoor                      Part + ProximityPrompt, tag "DarkRoomExit"
│   ├── ActiveAnomalies                       Folder   (runtime) live anomaly models
│   └── Decoys                                Folder   (runtime) False Alarm decoys
│
├── Lighting                                  (configured at runtime: night, fog, BaseGrade + AnomalyTint)
│
├── ReplicatedStorage
│   ├── Config                                Folder
│   │   ├── AnomalyConfig                     ModuleScript
│   │   ├── RarityConfig                      ModuleScript
│   │   ├── CameraConfig                      ModuleScript
│   │   ├── MonetizationConfig                ModuleScript
│   │   └── GameConfig                        ModuleScript
│   ├── Modules                               Folder
│   │   ├── Net                               ModuleScript
│   │   ├── Signal                            ModuleScript
│   │   ├── Cleaner                           ModuleScript
│   │   ├── Format                            ModuleScript
│   │   └── PhotoMath                         ModuleScript
│   └── Remotes                               Folder   (RemoteEvents/Functions created at runtime by Net.Setup)
│       ├── ClientReady, PhotoRequest, PhotoResult, PhotoFlash      RemoteEvent (runtime)
│       ├── DataUpdate, RoundUpdate, EventUpdate, Announce          RemoteEvent (runtime)
│       ├── AnomalyFx, RoundResults, SettingRequest, DarkRoomState  RemoteEvent (runtime)
│       └── ShopRequest, DarkRoomRequest                            RemoteFunction (runtime)
│
├── ServerScriptService
│   ├── Main                                  Script
│   ├── Services                              Folder
│   │   ├── MapService                        ModuleScript
│   │   ├── DataService                       ModuleScript
│   │   ├── MonetizationService               ModuleScript
│   │   ├── EconomyService                    ModuleScript
│   │   ├── CharacterService                  ModuleScript
│   │   ├── NPCService                        ModuleScript
│   │   ├── EventService                      ModuleScript
│   │   ├── AnomalyService                    ModuleScript
│   │   ├── PhotoService                      ModuleScript
│   │   ├── DarkRoomService                   ModuleScript
│   │   ├── RoundService                      ModuleScript
│   │   └── AdminService                      ModuleScript
│   └── Anomalies                             Folder
│       ├── AnomalyKit                        ModuleScript
│       └── Behaviors                         Folder
│           ├── ReverseClock                  ModuleScript
│           ├── FloatingCart                  ModuleScript
│           ├── FakeExit                      ModuleScript
│           ├── MovingDoor                    ModuleScript
│           ├── BlinkingLights                ModuleScript
│           ├── WalkingPainting               ModuleScript
│           ├── WatchingMannequin             ModuleScript
│           ├── FacelessShopper               ModuleScript
│           ├── FrozenCrowd                   ModuleScript
│           ├── WrongReflection               ModuleScript
│           ├── CeilingWatcher                ModuleScript
│           ├── FakePlayer                    ModuleScript
│           ├── SmilingPlayer                 ModuleScript
│           ├── OneBehindYou                  ModuleScript
│           ├── ThePhotographer               ModuleScript
│           ├── TheObserver                   ModuleScript
│           ├── TheNightManager               ModuleScript
│           ├── GlowingEyes                   ModuleScript
│           └── ShadowRunner                  ModuleScript
│
├── StarterPlayer
│   └── StarterPlayerScripts
│       ├── ClientMain                        LocalScript
│       └── Controllers                       Folder
│           ├── ClientState                   ModuleScript
│           ├── UIKit                         ModuleScript
│           ├── Sfx                           ModuleScript
│           ├── HUDController                 ModuleScript
│           ├── AnnouncementController        ModuleScript
│           ├── FxController                  ModuleScript
│           ├── PhotoController               ModuleScript
│           ├── AlbumController               ModuleScript
│           ├── ShopController                ModuleScript
│           ├── ResultsController             ModuleScript
│           ├── DarkRoomController            ModuleScript
│           └── ChatTagController             ModuleScript
│
├── StarterGui                                (contents are built by the controllers at runtime)
│   ├── HUD                                   ScreenGui  ResetOnSpawn=false, ScreenInsets=CoreUISafeInsets
│   ├── AlbumUI                               ScreenGui  ResetOnSpawn=false, DisplayOrder=10
│   ├── ResultsUI                             ScreenGui  ResetOnSpawn=false, DisplayOrder=20
│   ├── ShopUI                                ScreenGui  ResetOnSpawn=false, DisplayOrder=10
│   ├── DarkRoomUI                            ScreenGui  ResetOnSpawn=false, DisplayOrder=5
│   └── OverlayUI                             ScreenGui  ResetOnSpawn=false, ScreenInsets=None (full screen), DisplayOrder=50
│
└── TextChatService
    └── CaughtOnCameraCommands                Folder (runtime) admin TextChatCommands
```

The ScreenGuis in StarterGui are optional: if one is missing, its controller
creates it. The whole map is optional too: if `Workspace.Map.DeadMall` or
`Workspace.Lobby` already contain objects, MapService uses them instead of
building (see "Using your own map" in `docs/SETUP.md`).
