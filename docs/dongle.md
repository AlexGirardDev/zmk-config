# Adv360 Pro dongle mode

The Seeed XIAO nRF52840 runs as the split **central**. Both keyboard halves are
peripherals and connect to it over BLE; the dongle is the only thing that talks
to the host, over USB. Nothing pairs with the machine, so a KVM switches the
keyboard exactly like a wired one.

The keyboard does not work without the dongle -- peripherals cannot reach a host
on their own.

## Layout

| Target | Role |
| --- | --- |
| `seeeduino_xiao_ble` + `adv360pro_dongle` | central, USB to host |
| `adv360pro_left` | peripheral |
| `adv360pro_right` | peripheral |

Both halves already report globally-correct key positions into the shared 20x5
matrix transform (the right half applies `col-offset = <10>`), so the dongle
needs no per-peripheral position mapping -- just the same physical layout and a
mock kscan. That lives in `config/boards/shields/adv360pro_dongle/`.

`config/adv360pro.keymap` is shared by all three targets: ZMK derives the
candidate name `adv360pro` from the shield name `adv360pro_dongle`, so the
dongle picks up the same keymap and the same `config/adv360pro.conf`.

## Flashing gotchas

**The right half only enumerates with the original Kinesis cable.** Observed
first-hand, more than once. With other USB-C cables the right half may charge
but never present the `ADV360PRO` bootloader drive, no matter how clean the
double-click on the reset button is. The left half is not fussy in the same way.
If the right half refuses to show up, swap the cable before assuming the reset
button, the bootloader or the firmware is at fault.

**Also try flipping the USB-C connector over.** Rotating the plug 180 degrees in
the port has fixed this on its own. Both fixes together point at a marginal data
connection rather than anything Kinesis-specific -- one orientation of a given
cable carries the data pins, the other does not. So the working order when the
right half will not show up is:

1. Flip the USB-C connector over, at both ends.
2. Switch to the original Kinesis cable.
3. Only then start doubting the reset button, the bootloader or the firmware.

Keep the Kinesis cable with the keyboard so step 2 is always available.

Both halves also present the *same* volume label, `ADV360PRO`. Keep only one
half connected at a time so there is never a question which one is being
written.

## First-time setup

A settings reset is **required** whenever the split central changes. Skipping it
leaves stale bonds and a half that silently refuses to connect.

```bash
just build all

# 1. Reset every device (firmware/*settings_reset*.uf2), one at a time.
#    Double-tap reset to enter the bootloader.
# 2. Then flash the real firmware:
just flash
```

Flash order for `just flash` on the halves is left, then right.

## Travelling without the dongle

Easiest option: **take the dongle.** It is a USB stick, it works in a laptop,
and no firmware changes are involved.

If you genuinely need the halves to pair with a host directly (a tablet, or no
free USB port), switch the left half back to being the central:

1. In `config/adv360pro_left.conf`, set `CONFIG_ZMK_SPLIT_ROLE_CENTRAL=y` and
   remove (or comment out) `CONFIG_ZMK_USB=n`.
2. `just build adv360pro`
3. Settings-reset both halves, then flash left and right.

To come back to the dongle: revert those two lines, rebuild, then settings-reset
**all three** devices and reflash.

## Notes

- `config/settings_reset.conf` disables underglow and backlight for reset
  builds. This ZMK fork's battery underglow effect calls
  `zmk_battery_state_of_charge` unconditionally, and `settings_reset` turns
  battery reporting off, so the reset image does not link otherwise.
- Both halves build with `CONFIG_ZMK_USB=n`. A peripheral cannot present USB
  HID, and the board defconfig enables it unconditionally; setting it explicitly
  just keeps the build log clean. Bootloader flashing is unaffected.
- If the KVM ever fails to see the keyboard in BIOS/UEFI or right after a
  switch, uncomment `CONFIG_ZMK_USB_BOOT=y` in `config/adv360pro_dongle.conf`.
