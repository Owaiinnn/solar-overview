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

## Morning access check: 2026-10-07

Fresh Mac probes could not reach the battery or P1 reader. The owner confirmed
the Mac was on another network, so home-network checks could not proceed then.
This does not establish a device or app defect. Resume with fresh readings when
the Mac is home; do not compare new readings against yesterday's screenshots.

Real-device mobile setup, restart, off-network backoff and recovery remain open.
The probes above are Mac checks, not completed live Android app checks. Only an
Android emulator was available, and Xcode was unavailable for native iOS checks.
No battery controls or network settings were changed during these probes. The
existing automated and synthetic native checks remain separate evidence recorded
in the implementation ticket. Ticket 53 remains open for the unverified states,
timing, capacity, topology and mobile behavior.

## Resumed home-network verification: 2026-10-07

After the owner returned home, both local APIs responded with HTTP 200. Times
below are Europe/Amsterdam. These were read-only Mac probes and Android API 36
emulator checks against the real devices, not physical-phone verification.

At 18:45:12, the battery reported 42.6%, discharging (1002), pack DC 726 W,
inverter/total AC -661 W, charge counter 5.72 kWh and discharge counter 3.23 kWh.
Eight retained samples at 30-second intervals from 18:46:39 to 18:50:09 captured
idle followed by discharge. The idle sample was 42.5%, pack DC 26 W and both AC
fields 0 W; the subsequent discharge samples had positive pack power 690–694 W
and negative AC readings. This supports the sign convention during observed
discharge, but does not verify charging, bypass wiring or measurement alignment.
The sample run was interrupted after eight readings; no later samples from that
run are claimed.

The owner's 18:46 device-page screenshot shows 43%, Standby, AC Output 0 W,
Key Load 0 W, charged 5.72 kWh and discharged 3.23 kWh. These are nearby rather
than simultaneous readings: the 18:46:39 API sample had discharge counter
3.24 kWh. The screenshot's rounded SOC and standby/AC values are consistent with
the nearby sample. Idle with nonzero pack power remains an observation to explain;
no tolerance or normalization was changed. The screenshot's 2.62 kWh beside SOC
does not establish usable capacity. Today's lower charge counter than yesterday's
7.15 kWh is consistent with a reset between observations, but its exact timing and
completeness remain unverified.

An independent comparison did **not** pass: the owner's 18:59 home overview shows
43%, Standby, battery 26 W and grid export 116 W. Eight Mac probe pairs received
between 18:59:18 and 18:59:56 instead reported battery 40.0–40.1%, discharging,
pack DC 693–694 W, and P1 import 1,477–1,612 W with zero export. P1 source timestamps
advanced throughout that window. The overview's battery values resemble the
earlier standby sample, suggesting stale overview data, but the cause is not
established. After being asked to refresh/reopen the app, the owner reported
“40% now”, agreeing with the recent local SOC. This supports the stale-overview
hypothesis for SOC, but no updated state/grid values or exact sample time were
supplied. The state and grid discrepancy still needs a refreshed comparison. Do
not change signs or use the displayed zero household load from this evidence.

The agent completed these live emulator checks:

- Saved both local addresses through Settings; existing solar connections were
  retained. Details displayed real P1 measurements and battery SOC/state/pack
  power, with AC and daily counters available in the expanded battery section.
- Observed automatic foreground battery receipts at 18:52:39 and 18:53:14,
  consistent with the 30-second gate and five-second eligibility timer. The UI
  continued to state that the battery source time is unknown.
- Disabled only emulator Wi-Fi and mobile data. Both cards retained their last
  readings, reported the local-access failure and marked current data unavailable.
  Failure retry waits were visible; a later failed attempt increased the wait to
  about two minutes.
- Force-stopped and relaunched the app. Saved connections and readings survived.
  A second restart after networking was restored preserved the pending waits:
  P1/battery countdowns of 55/56 seconds at 18:56:45 became 30/32 seconds at
  18:57:10 rather than restarting or bypassing the gate.
- By 18:58:10 both connections had recovered automatically without manually
  refreshing, re-entering addresses or changing solar waits. Solar connections
  and their decreasing cooldowns remained present across restarts.
- Restored and checked emulator Wi-Fi and mobile data enabled, their initial
  states. No Mac network setting, battery control or device configuration changed.

A private test-helper assertion stopped the first sequence after force-stop;
its cleanup restored networking. The restart/recovery sequence was then continued
and verified separately. Private UI captures and samples remain outside git.
Rendered offline and connected states were inspected. No app code changed, so
automated app tests were not rerun for this evidence-only update. Physical Android,
native iOS (Xcode unavailable), charging, capacity, source timing, full backoff cap,
actual meter/device stale behavior and household AC topology remain open in #53
and #42.

On the owner's requested recheck at 19:06:27, the API reported battery 36.8%,
discharging, pack DC 2,451 W, inverter/total AC -2,240/-2,238 W and P1 export
1,761 W (import zero; meter time 19:06:26). At 19:07:53 it reported 35.9%,
pack DC 2,422 W and export 1,878 W (meter time 19:07:52). The agent visually
verified Solar Overview showing export 1.881 kW from meter time 19:07:27 and
battery 36%, discharging, with subsequent automatic battery updates. This verifies
that both app cards tracked the changed local readings after recovery. The later
export does not establish agreement with the earlier 18:59 vendor snapshot, and
these observations still do not authorize a household-balance calculation.
