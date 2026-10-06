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
- [Ticket 6 scope, evidence and outstanding checks](tickets/done/06-powerflex.md)
- [Ticket 53 device and measurement verification](tickets/53-battery-device-verification.md)

Installed module models, usable capacity, AC/bypass boundaries, device timestamps,
update cadence and day rollover must still be verified. Home flow graphics,
household balance and historical collection belong to later integrations.

## Dated device evidence: 2026-10-06

All times below are Europe/Amsterdam (UTC+02:00). These observations are historical;
they do not describe the current battery state. Raw responses, device identifiers,
addresses and owner screenshots are not included in the repository.

The agent ran read-only Mac HTTP probes on the home network. At 15:37:50 the
battery returned the following values. The owner supplied INDEVOLT screenshots
reported as approximately 15:40; their phone clock displays 15:39.

| Reading | Local API at 15:37:50 | Owner screenshot near 15:40 |
| --- | --- | --- |
| SOC | 100% | 100% |
| State | 1000, normalized idle | Standby |
| Pack DC power | 0 W | Battery 0 W |
| Inverter / total AC power | 0 W / 0 W | AC Output 0 W; Key Load 0 W |
| Daily charged / discharged | 7.15 / 1.11 kWh | Charged 7.15 / Discharged 1.11 kWh |
| Capacity field 142 | 6.05 kWh | 6.04 kWh beside SOC |

The nearby readings agree for idle SOC/state/power and the charge/discharge
counters. Zero power cannot establish AC/DC sign conventions or measurement
boundaries. Agreement in counter values supports the displayed scale for this
sample; it does not establish completeness, reset time or day-rollover behavior.
The capacity values differ, and the screenshot does not establish that its energy
value has the same meaning as field 142. Neither is verified usable capacity.

The owner's Settings screenshot identifies **PowerFlex 2000Eco**, **Key Load**
bypass and **Cluster: None**. The agent's system-config read at 15:37:28 reported
device type `CMS-SF2000` and firmware `V1.4.0E_R00D.0B2_M4801_0000003E`.
The commercial model comes from the screenshot, not the generic API type.
The hub image has a badge of 2; two module identifier slots returned nonempty
values. This is consistent with two modules but does not establish their models
or capacities. Field 6010 reported 6, the supported maximum, not an installed count.

The same-window P1 read reported meter time 15:37:49, import 0 W and export 997 W.
The owner's later overview shows solar 1.22 kW, export 760 W and load 460 W.
These readings were not synchronized, so neither a numerical grid comparison nor
a household balance is verified. The P1 timestamp was about one second old at
receipt in that sample; this does not establish sustained cadence. The battery's
system-config clock is not a measurement timestamp. A planned longer sampling
run has no retained result and is not counted as completed.

The successful battery request used compact JSON in the `config` query. An
earlier probe using spaced JSON returned an empty object. The app already sends
compact JSON; this observation required no normalization or client change.

## Follow-up status: 2026-10-07

Fresh Mac probes could not reach the battery or P1 reader. The owner confirmed
the Mac was on another network, so home-network checks cannot currently proceed.
This does not establish a device or app defect. Resume with fresh readings when
the Mac is home; do not compare new readings against yesterday's screenshots.

Real-device mobile setup, restart, off-network backoff and recovery remain open.
The probes above are Mac checks, not completed live Android app checks. Only an
Android emulator was available, and Xcode was unavailable for native iOS checks.
No battery controls or network settings were changed during these probes. The
existing automated and synthetic native checks remain separate evidence recorded
in the implementation ticket. Ticket 53 remains open for the unverified states,
timing, capacity, topology and mobile behavior.
