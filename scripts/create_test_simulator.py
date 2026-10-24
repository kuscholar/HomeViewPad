#!/usr/bin/env python3
"""Create (never erase/reuse) a dedicated test iPad and print its UUID.

Optional IOS_RUNTIME selects an exact installed identifier, e.g.
com.apple.CoreSimulator.SimRuntime.iOS-26-5. Otherwise use newest installed iOS.
"""
import json
import os
import subprocess


def simctl(*args):
    return subprocess.check_output(['xcrun', 'simctl', *args], text=True)


def main():
    runtimes = json.loads(simctl('list', 'runtimes', '-j'))['runtimes']
    wanted = os.environ.get('IOS_RUNTIME')
    available = [r for r in runtimes if r.get('isAvailable') and
                 r['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-') and
                 (not wanted or r['identifier'] == wanted)]
    if not available:
        raise SystemExit('No matching installed iOS runtime. Install one in Xcode; no automatic downloads are performed.')
    runtime = max(available, key=lambda r: tuple(map(int, r['version'].split('.'))))
    # Runtime-supported device types avoid selecting a newer iPad unsupported by this OS.
    devices = [d for d in runtime['supportedDeviceTypes'] if d['name'].startswith('iPad')]
    preferred = [d for d in devices if d['name'].startswith('iPad Pro 11-inch')]
    if not devices:
        raise SystemExit('Selected runtime has no supported iPad device type.')
    device = (preferred or devices)[-1]
    print(simctl('create', 'HomeViewPad-Tests', device['identifier'], runtime['identifier']).strip())


if __name__ == '__main__':
    main()
