#!/usr/bin/env python3

import pyudev
import subprocess

OUTPUT_NAME = 'HDMI-A-1'
TARGET_VENDOR_ID = '2109'
TARGET_PRODUCT_ID = '2817'

def main():
    context = pyudev.Context()
    monitor = pyudev.Monitor.from_netlink(context)
    monitor.filter_by(subsystem='usb')


    connected_targets = {}

    print("Monitoring USB devices... (Target: {}:{})".format(TARGET_VENDOR_ID, TARGET_PRODUCT_ID))

    for device in iter(monitor.poll, None):
        device_path = device.device_path
        action = device.action

        if action == 'add':
            vendor_id = device.get('ID_VENDOR_ID')
            product_id = device.get('ID_MODEL_ID')
            
            if vendor_id == TARGET_VENDOR_ID and product_id == TARGET_PRODUCT_ID:
                connected_targets[device_path] = True
                
                handle_device_connected()

        elif action == 'remove':
            if device_path in connected_targets:
                del connected_targets[device_path]
                handle_device_disconnected()

def handle_device_connected():
    print("Target USB device connected. Enabling output...")
    subprocess.run(['niri', 'msg', 'output', OUTPUT_NAME, 'on'])

def handle_device_disconnected():
    print("Target USB device disconnected. Disabling output...")
    subprocess.run(['niri', 'msg', 'output', OUTPUT_NAME, 'off'])

if __name__ == '__main__':
    main()