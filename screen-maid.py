#!/usr/bin/env python3

import argparse
import pyudev
import subprocess

MAIN_OUTPUT_NAME = 'DP-2'
SUB_OUTPUT_NAME = 'HDMI-A-1'
TARGET_VENDOR_ID = '2109'
TARGET_PRODUCT_ID = '2817'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sub', action='store_true')
    args = parser.parse_args()

    context = pyudev.Context()
    monitor = pyudev.Monitor.from_netlink(context)
    monitor.filter_by(subsystem='usb')


    connected_targets = {}

    print("Monitoring USB devices... (Target: {}:{})".format(TARGET_VENDOR_ID, TARGET_PRODUCT_ID))
    if args.sub:
        print("Sub mode")

    for device in iter(monitor.poll, None):
        device_path = device.device_path
        action = device.action

        if action == 'add':
            vendor_id = device.get('ID_VENDOR_ID')
            product_id = device.get('ID_MODEL_ID')
            
            if vendor_id == TARGET_VENDOR_ID and product_id == TARGET_PRODUCT_ID:
                connected_targets[device_path] = True
                
                handle_device_connected(args.sub)

        elif action == 'remove':
            if device_path in connected_targets:
                del connected_targets[device_path]
                handle_device_disconnected(args.sub)

def handle_device_connected(sub=False):
    print("Target USB device connected.")
    subprocess.run(['niri', 'msg', 'output', MAIN_OUTPUT_NAME, 'off' if sub else 'on'])
    subprocess.run(['niri', 'msg', 'output', SUB_OUTPUT_NAME, 'on' if sub else 'off'])

def handle_device_disconnected(sub=False):
    print("Target USB device disconnected.")
    pass
if __name__ == '__main__':
    main()