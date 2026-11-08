extends Node
## In-app purchase wrapper. Bala Kanda is free; the non-consumable
## "The Full Journey" product unlocks kandas 2-7.
##
## Real store integration (Google Play Billing plugin on Android, InAppStore on
## iOS) plugs in here. Until then this is a stub that can be toggled for testing.

signal entitlement_changed(owns_full_game: bool)
signal purchase_failed(reason: String)

const FULL_JOURNEY_PRODUCT_ID := "ramayana_full_journey"

## Debug override so designers can test locked chapters without a store.
@export var debug_unlock_all := false

var _owns_full_game := false


func _ready() -> void:
	if OS.is_debug_build() and OS.has_feature("editor"):
		debug_unlock_all = true
	restore_purchases()


func owns_full_game() -> bool:
	return _owns_full_game or debug_unlock_all


func has_store_backend() -> bool:
	return Engine.has_singleton("GodotGooglePlayBilling") or Engine.has_singleton("InAppStore")


func purchase_full_game() -> void:
	if not has_store_backend():
		purchase_failed.emit("Store not available on this platform build.")
		return
	# TODO(Phase 3): call into the platform billing plugin and await its callback.
	purchase_failed.emit("Store integration not implemented yet.")


## Entitlement always comes from the platform store, never from the local save.
func restore_purchases() -> void:
	if not has_store_backend():
		return
	# TODO(Phase 3): query owned products and call _set_entitlement().


func _set_entitlement(owned: bool) -> void:
	if owned == _owns_full_game:
		return
	_owns_full_game = owned
	entitlement_changed.emit(owned)
