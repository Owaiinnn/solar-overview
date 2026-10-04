# Local INDEVOLT battery monitoring

The app reads `POST /rpc/Indevolt.GetData` on port 8080 using a `config` query
containing an allowlisted `t` array. It supports owner-enabled unauthenticated
HTTP on private IPv4 addresses. It does not implement Digest, DNS discovery,
remote access, controls or a cloud service. No redirects are followed.

The address and normalized readings share one secure-storage record. Failed
connection tests retain the existing record. No raw response, identifier or
network error is logged. Solar providers retain their own HTTPS clients, storage
and refresh policies. The battery is not an additional solar source.

| Field | Normalized reading | Qualification |
| --- | --- | --- |
| 9405 | System SOC (%) | Only finite values from 0 through 100 |
| 6001 | Idle / charging / discharging | 1000 / 1001 / 1002; other values unknown |
| 6000 | Pack DC power (W) | Positive discharge, negative charge; separate from AC |
| 2275 | Inverter AC power (W) | Positive input, negative output; wiring unverified |
| 2278 | Total AC power (W) | May include bypass; never counted as solar |
| 6004 / 6005 | Daily charge / discharge (kWh) | Last reported counters, not confirmed totals for today |

Missing, malformed, negative energy or out-of-range SOC values remain unavailable;
zero stays zero. A response needs at least one usable SOC/state/pack-power field.
Numeric strings are not coerced. No capacity-based available energy is computed.
Conflicting state/power is flagged rather than used to infer a flow.

## Timing and refresh

Requests have an eight-second deadline covering headers and body, with an abort
signal on completion/timeout. The foreground app checks eligibility every five
seconds; successful reads wait at least 30 seconds. Failures wait 60, 120, 240,
then 300 seconds. The next attempt is saved before networking; storage failure
blocks networking until recovered. Disconnect keeps only the battery wait.
Automatic refresh pauses while editing a replacement, and no new request starts
in the background. Requests already in flight may finish and save their response.

A successful response is labelled recently received for under 90 seconds, unless
backgrounded or followed by a failed refresh. Restarted/cached readings are saved
only until a successful foreground read. Future receipt times are unknown. This
is a conservative UI receipt policy, not established device update cadence.
`measuredAt` remains null and `suitableForHouseholdBalance` is false. The API's
separate system clock must not be substituted for a measurement timestamp.

## Mobile network access

Android's main manifest permits cleartext HTTP because the user-configured IP
cannot be listed statically. The battery client restricts destinations to literal
RFC1918 IPv4 addresses and fixed port/path; solar clients remain HTTPS-only.
iOS declares local-network usage and `NSAllowsLocalNetworking`; permission and
IP-based HTTP behavior still require physical-device verification. No broad iOS
arbitrary-load exception is enabled.

Native tests use separate secure-storage keys and synthetic data. Preserve the
installed app and production records with:

```sh
flutter test integration_test/battery_storage_test.dart -d DEVICE_ID --no-uninstall
flutter test integration_test/battery_http_test.dart -d DEVICE_ID --no-uninstall
```

The HTTP test binds a synthetic server on the device's private IPv4 address at
port 8080, so it requires a connected private network interface and a free port.
It verifies the native HTTP client, not access to a real battery on the home LAN.

## References and remaining verification

- [Vendor HTTP setup](https://docs.indevolt.com/docs/hardware/open-data/http/)
- [Vendor field reference](https://docs.indevolt.com/docs/hardware/open-data/http-api/)
- [Android cleartext configuration](https://developer.android.com/privacy-and-security/security-config)
- [Apple local-network transport setting](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking)
- [Ticket 6 scope, evidence and outstanding checks](tickets/06-powerflex.md)

Exact model, firmware/modules, capacity, AC/bypass boundaries, device timestamps,
update cadence and day rollover must still be verified. Home flow graphics,
household balance and historical collection belong to later integrations.
