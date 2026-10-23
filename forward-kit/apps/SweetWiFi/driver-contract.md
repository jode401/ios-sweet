# SweetWiFi — driver contract

The boundary between the **app** (real Swift, this folder) and the **kernel Wi-Fi driver**
(does not exist yet; built on-device). The app only does *control* (scan / connect / status);
the *data* path is a kernel Ethernet interface, so every iOS app gets internet once connected.

**Status:** contract only. The driver is the hard on-device work.

## Two parts

1. **Data path — present Wi-Fi as Ethernet.** The driver exposes a kernel `ifnet` of type Ethernet
   (the same approach as ios-sweet's USB `ue0`). Once associated + DHCP'd, iOS routes **all** app
   traffic (Safari, Mail, the App Store's networking) over it — no per-app work. The genuine
   Settings/Control-Center Wi-Fi widget is **not** wired (that needs Apple's closed `IO80211`; out of scope).

2. **Control interface — IOKit user client `SweetWiFi`.** This is all the app talks to.

## External methods (`IOConnectCallStructMethod`)

| Selector | Name | Input struct | Output struct |
|---|---|---|---|
| 0 | `scan` | — | `uint32 count` then `count` × `Network` |
| 1 | `connect` | `Connect` | — |
| 2 | `status` | — | `Status` |
| 3 | `disconnect` | — | — |

### Struct layouts (keep in sync with `SweetWiFiClient.swift`)

```
Network  (36 bytes): char ssid[32]; int8 rssi; uint8 flags (bit0 = secured); uint8 pad[2]
Connect  (96 bytes): char ssid[32]; char psk[64]
Status   (8 bytes):  uint32 state (0 down,1 scanning,2 associating,3 connected,4 failed); uint8 ip[4]
```

## Driver responsibilities (on-device)

1. Bring up the Wi-Fi core (Snapdragon WCNSS) from the phone's own signed firmware; reference the
   ISC-licensed `wcn36xx` protocol (do not copy GPL code into the kernel).
2. 802.11 scan; return results to `scan`.
3. Authentication + **WPA2 4-way handshake** (run `wpa_supplicant`, BSD-licensed, as a helper, or in-driver).
4. On success, bring the Ethernet `ifnet` up and get an address via **DHCP** (configd). ios-sweet already
   hit the case where configd ignores a non-`IONetworkInterface`; present a proper `IONetworkInterface`.
5. Report state/IP to `status`.

## Bring-up gates (on device)
1. Firmware boots, control channel up.
2. `scan` returns a known SSID.
3. `connect` associates + WPA2 + DHCP; `status` = connected with an IP.
4. **Safari loads an HTTPS page** (proves internet for all apps). Reconnect works.
