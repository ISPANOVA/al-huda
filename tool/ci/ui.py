"""Tiny UI driver for the emulator: tap a Flutter widget by its label.

Flutter exposes its semantics to Android accessibility, so uiautomator sees
every Text / tooltip as text or content-desc.
  python3 tool/ci/ui.py tap 'المصحف'      -> taps the smallest matching node
  python3 tool/ci/ui.py dump out.txt      -> writes all labels with bounds
"""
import re, subprocess, sys

def dump():
    subprocess.run(['adb', 'shell', 'uiautomator', 'dump', '/sdcard/ui.xml'], capture_output=True, timeout=60)
    xml = subprocess.run(['adb', 'shell', 'cat', '/sdcard/ui.xml'], capture_output=True, timeout=30).stdout.decode('utf-8', 'replace')
    nodes = []
    for m in re.finditer(r'<node [^>]*>', xml):
        n = m.group(0)
        text = re.search(r' text="([^"]*)"', n).group(1) if ' text="' in n else ''
        desc = re.search(r' content-desc="([^"]*)"', n).group(1) if ' content-desc="' in n else ''
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', n)
        if not b:
            continue
        x1, y1, x2, y2 = map(int, b.groups())
        label = (text + ' ' + desc).strip().replace('&#10;', ' ')
        if label:
            nodes.append((label, x1, y1, x2, y2))
    return nodes

if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'dump':
        with open(sys.argv[2], 'w', encoding='utf-8') as f:
            for n in dump():
                f.write(f'{n}\n')
    elif cmd == 'tapxy':
        # Fractions of the screen (fallback when a widget has no label).
        size = subprocess.run(['adb', 'shell', 'wm', 'size'], capture_output=True).stdout.decode()
        w, h = map(int, re.search(r'(\d+)x(\d+)', size).groups())
        x, y = int(float(sys.argv[2]) * w), int(float(sys.argv[3]) * h)
        print(f'tapxy {x},{y}')
        subprocess.run(['adb', 'shell', 'input', 'tap', str(x), str(y)])
    elif cmd == 'tap':
        want = sys.argv[2]
        # Off-screen widgets report empty bounds: never tap those.
        nodes = [n for n in dump() if want in n[0] and n[3] > n[1] and n[4] > n[2]]
        if not nodes:
            print(f'NOT FOUND: {want}')
            sys.exit(0)
        nodes.sort(key=lambda n: (n[3] - n[1]) * (n[4] - n[2]))
        label, x1, y1, x2, y2 = nodes[0]
        print(f'tap {want!r} -> {label!r} at {(x1 + x2) // 2},{(y1 + y2) // 2}')
        subprocess.run(['adb', 'shell', 'input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2)])
