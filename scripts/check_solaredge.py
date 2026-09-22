#!/usr/bin/env python3
"""Read-only SolarEdge Monitoring API check; Python 3 standard library only."""

import argparse
import getpass
import json
import math
import os
import re
import sys
from datetime import datetime
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import HTTPRedirectHandler, Request, build_opener


class NoRedirect(HTTPRedirectHandler):
    """Do not forward a credential-bearing request through a redirect."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class CheckError(Exception):
    pass


def number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def fetch(site_id, key, endpoint, params=None):
    query = dict(params or {})
    query['api_key'] = key
    url = 'https://monitoringapi.solaredge.com/site/{}/{}?{}'.format(
        site_id, endpoint, urlencode(query)
    )
    request = Request(url, headers={'Accept': 'application/json'})
    try:
        with build_opener(NoRedirect()).open(request, timeout=25) as response:
            return json.load(response)
    except HTTPError as error:
        hints = {
            401: 'credentials rejected',
            403: 'access denied; verify key and site access',
            404: 'site or endpoint not found',
            429: 'rate limit reached; stop and retry later',
        }
        raise CheckError('HTTP {} ({})'.format(error.code, hints.get(error.code, 'request failed'))) from None
    except (URLError, TimeoutError, OSError):
        # Exception strings and URLs can contain the API key. Never print them.
        raise CheckError('Network/TLS request failed; verify network access and certificate setup.') from None
    except (ValueError, TypeError):
        raise CheckError('Response was not valid JSON.') from None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--credentials-stdin', action='store_true',
                        help='Read a JSON object with site_id and api_key from stdin.')
    args = parser.parse_args()
    try:
        if args.credentials_stdin:
            credentials = json.load(sys.stdin)
            site_id = str(credentials['site_id']).strip()
            key = str(credentials['api_key']).strip()
        else:
            site_id = os.getenv('SOLAREDGE_SITE_ID') or input('SolarEdge site ID: ').strip()
            key = os.getenv('SOLAREDGE_API_KEY') or getpass.getpass('SolarEdge API key (hidden): ').strip()
        if not re.fullmatch(r'[0-9]+', site_id) or not re.fullmatch(r'[A-Za-z0-9]{16,128}', key):
            raise ValueError()
    except (ValueError, KeyError, TypeError, EOFError):
        print('Invalid or missing credentials. Values have not been logged.', file=sys.stderr)
        return 1

    try:
        payload = fetch(site_id, key, 'overview')
        overview = payload.get('overview') if isinstance(payload, dict) else None
        if not isinstance(overview, dict):
            raise CheckError('Expected overview data was missing.')
        print('Overview: connected successfully')
        stamp = overview.get('lastUpdateTime')
        try:
            last_update = datetime.strptime(stamp, '%Y-%m-%d %H:%M:%S')
        except (ValueError, TypeError):
            last_update = None
        print('Last update (site local time):', last_update.isoformat(' ') if last_update else 'unavailable')
        for label, field, unit in [('Current production', 'currentPower', 'W'),
                                   ('Today’s energy', 'lastDayData', 'Wh')]:
            entry = overview.get(field)
            value = entry.get('power' if field == 'currentPower' else 'energy') if isinstance(entry, dict) else None
            print('{}: {}'.format(label, '{} {}'.format(value, unit) if number(value) else 'unavailable'))

        # Query the day of the most recent overview reading, without assuming UTC.
        if last_update:
            day = last_update.strftime('%Y-%m-%d')
            history = fetch(site_id, key, 'power', {
                'startTime': day + ' 00:00:00', 'endTime': day + ' 23:59:59'
            })
            power = history.get('power') if isinstance(history, dict) else None
            if not isinstance(power, dict) or power.get('unit') != 'W' or not isinstance(power.get('values'), list):
                raise CheckError('Power history did not contain the expected W-valued series.')
            readings = power['values']
            present = [p['value'] for p in readings if isinstance(p, dict) and number(p.get('value'))]
            print('Power history for {}: {} measured points; {} missing/non-numeric points'.format(
                day, len(present), len(readings) - len(present)))
            if present:
                print('Highest returned power: {} W'.format(max(present)))

        flow = fetch(site_id, key, 'currentPowerFlow')
        flow = flow.get('siteCurrentPowerFlow') if isinstance(flow, dict) else None
        if isinstance(flow, dict):
            for field in ['PV', 'LOAD', 'GRID', 'STORAGE']:
                item = flow.get(field)
                available = isinstance(item, dict) and number(item.get('currentPower'))
                print('{} power field: {}'.format(field, 'present (coverage not verified)' if available else 'unavailable'))
        else:
            print('Power-flow data unavailable; household consumption is not established.')
        print('Read-only check finished. No credentials or raw API responses were saved.')
        return 0
    except CheckError as error:
        print('Check stopped: {}'.format(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
