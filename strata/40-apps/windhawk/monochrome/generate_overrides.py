"""Generate Windhawk styler overrides that recolour glass themes to OLED monochrome.

Only colour properties are emitted (Background/Fill/BorderBrush/Stroke); layout is untouched.
Output: JSON {mod_id: {setting_name: value}} for the elevated apply script.
"""
import json, re, sys

SRC = 'C:/ProgramData/Windhawk/ModsSource/%s.wh.cpp'
STR = r'L"((?:[^"\\]|\\.)*)"'

BLACK_FILL = '<WindhawkBlur BlurAmount="7" TintColor="#D9000000"/>'
FLAT_BORDER = '<SolidColorBrush Color="#33FFFFFF"/>'
SOFT_WHITE = '<SolidColorBrush Color="#14FFFFFF"/>'

# Elements that must stay see-through (screen dimming, invisible strokes)
SKIP_TARGETS = ('BackgroundDimmingLayer',)


def theme_rules(mod, theme):
    src = open(SRC % mod, encoding='utf-8', errors='replace').read()
    start = src.index('const Theme g_theme%s = {{' % theme)
    nxt = src.find('\nconst Theme g_theme', start + 10)
    block = src[start:nxt if nxt != -1 else len(src)]
    for tgt, body in re.findall(r'ThemeTargetStyles\{' + STR + r',\s*\{(.*?)\}\},', block, re.S):
        yield tgt.replace('\\"', '"'), [s.replace('\\"', '"') for s in re.findall(STR, body)]


def tint(s):
    m = re.search(r'TintColor="#([0-9A-Fa-f]{8})"', s)
    return m.group(1) if m else None


def recolour(style):
    m = re.match(r'^(Background|Fill|BorderBrush|Stroke)((?:@[A-Za-z]+)?)\s*:=\s*(.*)$', style)
    if not m:
        return None
    prop, state, val = m.groups()
    head = '%s%s:=' % (prop, state)
    if prop in ('BorderBrush', 'Stroke'):
        if 'LinearGradientBrush' in val or 'WindhawkBlur' in val:
            t = tint(val)
            if t and t[:2] == '00':
                return None  # fully transparent stroke: leave
            return head + FLAT_BORDER
        return None
    # Background / Fill
    if 'WindhawkBlur' in val:
        t = tint(val)
        if not t or t[:2] == '00':
            return None
        r, g, b = (int(t[i:i + 2], 16) for i in (2, 4, 6))
        if max(r, g, b) <= 0x60:          # dark glass -> OLED black
            if state in ('@PointerOver', '@Pressed', '@PointerOverSelected', '@PressedSelected'):
                return head + '<SolidColorBrush Color="#1FFFFFFF"/>'  # keep hover feedback visible
            return head + BLACK_FILL
        return None                        # white overlays are already monochrome
    if 'LinearGradientBrush' in val and re.search(r'#[0-9A-Fa-f]{2}[fF]0[fF]07[dD]', val):
        return head + SOFT_WHITE           # yellow-tinted glass highlight
    return None


def overrides(mod, theme):
    out = []
    for tgt, styles in theme_rules(mod, theme):
        if any(s in tgt for s in SKIP_TARGETS):
            continue
        new = [n for n in (recolour(s) for s in styles) if n]
        if new:
            out.append((tgt, new))
    return out


def control_styles(rules, start=0):
    settings = {}
    for i, (tgt, styles) in enumerate(rules, start):
        settings['controlStyles[%d].target' % i] = tgt
        for j, s in enumerate(styles):
            settings['controlStyles[%d].styles[%d]' % (i, j)] = s
    return settings


result = {}

tb = overrides('windows-11-taskbar-styler', 'LiquidGlass2')
result['windows-11-taskbar-styler'] = control_styles(tb)

sm = overrides('windows-11-start-menu-styler', 'LiquidGlass2')
s = control_styles(sm)
consts = [
    'GlassDark=' + BLACK_FILL,
    'GlassDark2=<WindhawkBlur BlurAmount="0" TintColor="#00000000"/>',
    'GlassDarkTitles=<WindhawkBlur BlurAmount="7" TintColor="#140A0A0A"/>',
    'GlassDarkBottomTray=<WindhawkBlur BlurAmount="7" TintColor="#F20A0A0A"/>',
    'GlassDarkSearchPage=' + BLACK_FILL,
    'BorderBrush=' + FLAT_BORDER,
    'ElementBorderBrush=<SolidColorBrush Color="#28FFFFFF"/>',
    'fluidBorder=<SolidColorBrush Color="#28FFFFFF"/>',
]
for i, c in enumerate(consts):
    s['styleConstants[%d]' % i] = c
result['windows-11-start-menu-styler'] = s

nc = overrides('windows-11-notification-center-styler', 'TranslucentShell')
s = control_styles(nc)
s['styleConstants[0]'] = 'CommonBgBrush=' + BLACK_FILL
result['windows-11-notification-center-styler'] = s

fe = overrides('windows-11-file-explorer-styler', 'OS26_Liquid_Glass_variant_Compact')
result['windows-11-file-explorer-styler'] = control_styles(fe)

json.dump(result, open(sys.argv[1], 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
for mod, st in result.items():
    n = len([k for k in st if k.endswith('.target')])
    print('%-42s %3d override rules, %3d values' % (mod, n, len(st)))
