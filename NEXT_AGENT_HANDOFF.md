# Handoff: Dynamic Sprite Adjustment for Bob

## Objective
Implement and polish the dynamic sprite swap for the pet "Bob" when the **Flower Crown** is equipped.

## Current State
- **Trigger**: Equipping `hat_spring` (Flower Crown) triggers a switch to `BobTheFruity.png`.
- **Implementation**: Located in `lib/game/bob_the_blob.dart`.
- **Key Logic**:
    - `_loadSprite()`: Sets `frameWidth=29`, `frameHeight=33` and `_frameOffset=Vector2(-2, -2)` for the Fruity sprite.
    - `_getSourceRectForFrame()`: Applies the `_frameOffset` to the `x` and `y` source coordinates to capture the symmetric 2px expansion.
    - `onGameResize()`: Manually called after sprite swap to ensure the component's `size` (and hitbox) matches the new aspect ratio.

## Status/Issues
- The user reported a shift when the Fruity sprite was active. 
- The current implementation uses a `-2` offset to pull the source rectangle left/up, which should center the blob content if it was expanded symmetrically by 2px on all sides.
- **Next Step**: Verify that switching between "Hatless" and "Flower Crown" keeps Bob's body in the exact same position on screen. Adjust the values in `_loadSprite` if a slight shift remains.
