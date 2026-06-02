#!/usr/bin/env python3

import subprocess
import time
from Xlib import X, display
from Xlib.ext import record
from Xlib.protocol import rq

d = display.Display()
root = d.screen().root

scrolling = False
anchor_y = 0
deadzone = 10
speed = 0.02


def get_mouse():
    data = root.query_pointer()
    return data.root_x, data.root_y


def scroll(amount):
    button = "5" if amount > 0 else "4"
    for _ in range(abs(amount)):
        subprocess.call(["xdotool", "click", button],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL)


def toggle_scroll():
    global scrolling, anchor_y
    x, y = get_mouse()
    if not scrolling:
        anchor_y = y
        scrolling = True
    else:
        scrolling = False


def handler(reply):
    global scrolling

    if reply.category != record.FromServer:
        return
    if reply.client_swapped:
        return
    if not len(reply.data):
        return

    data = reply.data
    while len(data):
        event, data = rq.EventField(None).parse_binary_value(
            data, d.display, None, None)

        if event.type == X.ButtonPress and event.detail == 2:
            toggle_scroll()


ctx = d.record_create_context(
    0,
    [record.AllClients],
    [{
        'core_requests': (0, 0),
        'core_replies': (0, 0),
        'ext_requests': (0, 0, 0, 0),
        'ext_replies': (0, 0, 0, 0),
        'delivered_events': (0, 0),
        'device_events': (X.ButtonPress, X.ButtonPress),
        'errors': (0, 0),
        'client_started': False,
        'client_died': False,
    }]
)

import threading


def scroll_loop():
    global scrolling

    while True:
        if scrolling:
            x, y = get_mouse()
            dy = y - anchor_y

            if abs(dy) > deadzone:
                steps = int(dy / 20)
                if steps != 0:
                    scroll(steps)

        time.sleep(speed)


threading.Thread(target=scroll_loop, daemon=True).start()

d.record_enable_context(ctx, handler)
d.record_free_context(ctx)
