extends Node
## EventBus (autoload)
##
## Global, decoupled signal hub. Systems never reference each other directly
## when a signal is enough: they emit here and whoever cares listens.
## This is what keeps the architecture free of circular dependencies:
##   Player  --emit-->  EventBus  --signal-->  HUD / Audio / Satella / Director

# --- Player ------------------------------------------------------------------
signal player_spawned(player: Node)
signal player_died(cause: String)
signal player_panic_changed(panic: float)
signal player_zone_changed(zone_id: String)
signal flashlight_toggled(on: bool)
signal flashlight_battery_changed(ratio: float)
signal flashlight_flicker_requested(duration: float, intensity: float)

# --- Interaction / UI --------------------------------------------------------
signal interaction_prompt_changed(text: String, can_interact: bool)
signal note_opened(note_id: String, title: String, body: String, author: String)
signal note_closed
signal inspect_requested(item_node: Node3D, title: String, description: String)
signal inspect_closed
signal toast(text: String)
signal objective_changed(text: String)
signal chapter_title(index: int, title: String, subtitle: String)
signal ui_modal_opened
signal ui_modal_closed

# --- Narrative ---------------------------------------------------------------
signal dialogue_line(speaker: String, text: String, duration: float, style: String)
signal dialogue_cleared
signal fragment_collected(fragment_id: String)
signal fragment_inserted(fragment_id: String)
signal flag_set(flag: String, value: Variant)
signal chapter_started(index: int)
signal ending_reached(ending_id: String)

# --- Satella / Horror --------------------------------------------------------
signal awareness_changed(value: float, stage: int)
signal awareness_stage_changed(stage: int, stage_name: String)
signal satella_state_changed(state_name: String)
signal satella_seen(seconds: float)
signal satella_request(command: String, args: Dictionary)
signal jumpscare_started(id: String)
signal jumpscare_ended(id: String)
signal horror_event(id: String)
signal chase_started(chase_id: String)
signal chase_ended(chase_id: String, escaped: bool)
signal world_distortion(intensity: float, duration: float)
signal camera_shake(strength: float, duration: float)
signal screen_glitch(strength: float, duration: float)

# --- Loops -------------------------------------------------------------------
signal checkpoint_reached(checkpoint_id: String)
signal loop_started(loop_index: int, deaths: int)
signal game_saved
signal game_loaded
