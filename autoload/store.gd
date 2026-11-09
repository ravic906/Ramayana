extends Node
## In-app purchases. Part 1 is free. Each later Part can be bought on its own
## (product "ramayana_part_NN"), or the "Full Journey" bundle unlocks every
## current and future Part. All products are non-consumable.
##
## Real store integration (Google Play Billing plugin on Android, InAppStore on
## iOS) plugs in here. Until then purchases report "available soon";
## entitlements always come from the platform store, never from the save file.

signal entitlements_changed
signal purchase_failed(product_id: String, reason: String)
## Legacy signal kept for older callers.
signal entitlement_changed(owns_full_game: bool)

const FULL_JOURNEY_PRODUCT_ID := "ramayana_full_journey"
const FULL_JOURNEY_PRICE := "₹699"

## Debug override so designers can test locked Parts without a store.
@export var debug_unlock_all := false

var _owned := {}


func _ready() -> void:
	if OS.is_debug_build() and OS.has_feature("editor"):
		debug_unlock_all = true
	restore_purchases()


func all_product_ids() -> PackedStringArray:
	var ids := PackedStringArray([FULL_JOURNEY_PRODUCT_ID])
	for part in PartCatalog.all():
		if not part.product_id.is_empty():
			ids.append(part.product_id)
	return ids


func owns_product(product_id: String) -> bool:
	return debug_unlock_all or (not product_id.is_empty() and _owned.has(product_id))


func owns_full_journey() -> bool:
	return owns_product(FULL_JOURNEY_PRODUCT_ID)


## Legacy name.
func owns_full_game() -> bool:
	return owns_full_journey()


func has_store_backend() -> bool:
	return Engine.has_singleton("GodotGooglePlayBilling") or Engine.has_singleton("InAppStore")


func purchase(product_id: String) -> void:
	if not product_id in all_product_ids():
		purchase_failed.emit(product_id, "Unknown product.")
		return
	if not has_store_backend():
		purchase_failed.emit(product_id, "Purchases will be available when this Part is released on the store.")
		return
	# TODO(Phase 3): call into the platform billing plugin and await its callback,
	# then grant(product_id) on success.
	purchase_failed.emit(product_id, "Store integration not implemented yet.")


## Legacy name.
func purchase_full_game() -> void:
	purchase(FULL_JOURNEY_PRODUCT_ID)


func restore_purchases() -> void:
	if not has_store_backend():
		return
	# TODO(Phase 3): query owned products and grant() each.


## Records an owned product (called by the billing backend; tests use it too).
func grant(product_id: String) -> void:
	if _owned.has(product_id):
		return
	_owned[product_id] = true
	entitlements_changed.emit()
	if product_id == FULL_JOURNEY_PRODUCT_ID:
		entitlement_changed.emit(true)


func revoke_all() -> void:
	_owned.clear()
	entitlements_changed.emit()
	entitlement_changed.emit(false)
