---
name: wake-on-lan
description: Power on Scylla remotely by sending a Wake-on-LAN magic packet from another machine on its network. Use when asked to wake, boot, or power on Scylla, or when a magic packet does not wake it.
---

# Wake Scylla over the network

Scylla can be powered on with a Wake-on-LAN (WoL) magic packet. Magic packets are layer-2 broadcasts, so the sender must sit on the same network; a routed or tunneled path such as Tailscale alone will not reach it.

## Find the identifiers

Do not hardcode the interface, MAC, or broadcast address here — they belong to the host. Collect them from Scylla while it is running:

```sh
ip -br link                        # the interface that is UP and has a carrier
cat /sys/class/net/<interface>/address
ip -4 addr show <interface>        # read brd and the prefix length
```

Use the `brd` value as the broadcast address. If it is missing, derive it from the address/prefix in the same output — for example a `/22` broadcasts on the last address of that /22, not on the gateway.

The MAC must be permanent. Check `cat /sys/class/net/<interface>/addr_assign_type`: `0` means the address is burned in and stable across boots. Any other value means software generates it, so pin it in the host's NixOS config (`networking.interfaces.<interface>.macAddress`) before relying on WoL.

Once Scylla is off, these values are no longer discoverable on the machine itself: ARP and `ip neigh` will not know it. Look them up in the router's DHCP lease table (match the hostname) or keep them with the host's records.

## Send the packet

`wakeonlan` is installed on every host:

```sh
wakeonlan -i <broadcast-address> <mac>
```

Passing `-i` matters on machines with several interfaces; the default destination is the limited broadcast address, which can leave through the wrong one.

## Verify

- The link LED on Scylla's NIC should stay lit while the machine is powered off. If it is dark, the slot has no standby power and no packet will help.
- After boot, `sudo nix shell nixpkgs#ethtool -c ethtool <interface>` must report `Wake-on: g`, and `Supports Wake-on:` must contain `g`. `g` is the magic-packet option.
- `/proc/acpi/wakeup` should list the NIC's PCI address with an `*enabled` status.

## When it does not wake

Check the layers in order:

1. **BIOS/UEFI.** ErP must be disabled so the slot keeps standby power, and PCIe or onboard-LAN wake must be enabled. This is the most common failure, and the OS cannot fix it.
2. **Host config.** The machine file sets `networking.interfaces.<interface>.wakeOnLan.enable = true;`, which renders a systemd `.link` with `WakeOnLan=magic`. `.link` files are applied at device add, so reboot after changing it rather than expecting it to take effect immediately.
3. **NetworkManager.** A connection-level `wake-on-lan` of `default` (the default) or `ignore` leaves the setting alone. A value of `0`, or `ethernet.wake-on-lan=0` in `NetworkManager.conf`, disables WoL on every activation.
4. **Sender.** Confirm the sender is on the same subnet and that the packet goes out the interface facing Scylla. A host on that LAN reachable through Tailscale can relay the packet if you are remote.

To enable WoL on another host, set `networking.interfaces.<interface>.wakeOnLan.enable = true;` in its machine file and repeat the BIOS check.
