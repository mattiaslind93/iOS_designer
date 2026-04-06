#!/usr/bin/env python3
"""Generate a camera app DesignDocument (.iosdesign) matching Swift Codable format."""
import json, uuid, sys, os

def uid(): return str(uuid.uuid4()).upper()

# --- Colors ---
def custom(r, g, b, a=1.0):
    return {"custom": {"red": r, "green": g, "blue": b, "opacity": a}}

def system(name):
    return {"system": {"_0": name}}

black = custom(0, 0, 0)
white = custom(1, 1, 1)
warm_orange = custom(0.93, 0.58, 0.35)
warm_orange_dim = custom(0.93, 0.58, 0.35, 0.7)
red_c = custom(0.9, 0.2, 0.2)
dim_white = custom(1, 1, 1, 0.7)
light_gray = custom(0.6, 0.6, 0.6)
mid_gray = custom(0.25, 0.25, 0.25)
grid_line = custom(1, 1, 1, 0.15)
vf_bg = custom(0.35, 0.30, 0.25)

# --- Modifier helpers ---
def frame(w=None, h=None, alignment=None):
    d = {}
    if w is not None: d["width"] = w
    if h is not None: d["height"] = h
    if alignment is not None: d["alignment"] = alignment
    return {"frame": d}

def padding(edges, amount):
    return {"padding": {"edges": edges, "amount": amount}}

def fg(color):
    return {"foregroundStyle": {"_0": color}}

def bg(color):
    return {"background": {"_0": color}}

def tint(color):
    return {"tint": {"_0": color}}

def opacity(v):
    return {"opacity": {"_0": v}}

def font(style=None, size=None, weight=None, design=None):
    d = {}
    if style: d["style"] = style
    if size: d["size"] = size
    if weight: d["weight"] = weight
    if design: d["design"] = design
    return {"font": d}

def corner_radius(r):
    return {"cornerRadius": {"_0": r}}

def clip_shape(s):
    return {"clipShape": {"_0": s}}

def overlay_border(shape, color, line_width):
    return {"overlay": {"_0": shape, "color": color, "lineWidth": line_width}}

def shadow(color, radius, x=0, y=0):
    return {"shadow": {"color": color, "radius": radius, "x": x, "y": y}}

def blur(radius):
    return {"blur": {"radius": radius}}

def glass_effect(style):
    return {"glassEffect": {"_0": style}}

def glass_config(style="regular", tint_color=None, tint_intensity=0.2, interactive=False, shape="capsule"):
    cfg = {"style": style, "tintIntensity": tint_intensity, "isInteractive": interactive, "shape": shape}
    if tint_color is not None:
        cfg["tintColor"] = tint_color
    return {"glassConfig": {"_0": cfg}}

def offset(x, y):
    return {"offset": {"x": x, "y": y}}

def z_index(v):
    return {"zIndex": {"_0": v}}

def bg_material(m):
    return {"backgroundMaterial": {"_0": m}}

# --- Payload helpers ---
def vstack(spacing=None, alignment="center"):
    d = {"alignment": alignment}
    if spacing is not None: d["spacing"] = spacing
    return {"vStack": d}

def hstack(spacing=None, alignment="center"):
    d = {"alignment": alignment}
    if spacing is not None: d["spacing"] = spacing
    return {"hStack": d}

def zstack(alignment="center"):
    return {"zStack": {"alignment": alignment}}

def text(content, style=None):
    d = {"content": content}
    if style: d["style"] = style
    return {"text": d}

def image(system_name=None):
    d = {}
    if system_name: d["systemName"] = system_name
    return {"image": d}

def spacer(min_length=None):
    d = {}
    if min_length is not None: d["minLength"] = min_length
    return {"spacer": d}

rectangle = {"rectangle": {}}
circle_p = {"circle": {}}
capsule_p = {"capsule": {}}
divider_p = {"divider": {}}

def rounded_rect(r):
    return {"roundedRectangle": {"cornerRadius": r}}

def label_p(title, sys_image):
    return {"label": {"title": title, "systemImage": sys_image}}

# --- Node helper ---
def node(name, payload, mods=None, children=None):
    n = {
        "id": uid(),
        "name": name,
        "payload": payload,
        "modifiers": mods or [],
        "children": children or [],
        "isLocked": False,
        "isVisible": True,
    }
    return n


# ============================================================
#  BUILD THE CAMERA UI
# ============================================================

# ---- TOP BAR ----

auto_badge = node("AUTO Badge", text("AUTO"), [
    font(size=13, weight="bold", design="rounded"),
    fg(red_c),
    padding("horizontal", 12),
    padding("vertical", 5),
    overlay_border("capsule", red_c, 1.5),
])

exposure_btn = node("Exposure", hstack(4, "center"), [
    padding("horizontal", 12),
    padding("vertical", 6),
    glass_config("regular", None, 0.2, True, "capsule"),
], [
    node("Exp Icon", image("plusminus"), [
        font(size=14, weight="medium"),
        fg(white),
    ]),
    node("Exp Val", text("±0"), [
        font(size=14, weight="semibold", design="monospaced"),
        fg(white),
    ]),
])

flash_btn = node("Flash", image("bolt.slash.fill"), [
    font(size=16, weight="medium"),
    fg(white),
    frame(36, 36),
    glass_config("regular", None, 0.2, True, "circle"),
])

top_bar = node("Top Bar", hstack(8, "center"), [
    padding("horizontal", 16),
    padding("vertical", 8),
], [
    auto_badge,
    node("Spacer", spacer()),
    exposure_btn,
    flash_btn,
])


# ---- VIEWFINDER ----

def grid_v(name, x_off):
    return node(name, rectangle, [
        frame(0.5, None),
        fg(grid_line),
        offset(x_off, 0),
    ])

def grid_h(name, y_off):
    return node(name, rectangle, [
        frame(None, 0.5),
        fg(grid_line),
        offset(0, y_off),
    ])

viewfinder = node("Viewfinder", zstack(), [
    frame(None, 480),
    corner_radius(4),
    clip_shape("roundedRectangle"),
], [
    node("VF BG", rounded_rect(4), [fg(vf_bg)]),
    # Cup/circle in center
    node("Cup", circle_p, [
        frame(120, 120),
        fg(custom(0.2, 0.18, 0.14, 0.8)),
        shadow(custom(0, 0, 0, 0.3), 20),
    ]),
    # Grid lines
    grid_v("Grid V1", -60),
    grid_v("Grid V2", 60),
    grid_h("Grid H1", -80),
    grid_h("Grid H2", 80),
])


# ---- LIGHT METER ----

def tick(label_text, bold=False):
    w = "bold" if bold else "medium"
    s = 10 if bold else 9
    c = white if bold else dim_white
    return node(label_text, text(label_text), [
        font(size=s, weight=w, design="monospaced"),
        fg(c),
    ])

ticks = [tick("-3"), tick("-2"), tick("-1"), tick("0", True), tick("+1"), tick("+2"), tick("+3")]
tick_children = []
for i, t in enumerate(ticks):
    tick_children.append(t)
    if i < len(ticks) - 1:
        tick_children.append(node(f"TSp{i}", spacer()))

light_meter = node("Light Meter", vstack(4, "center"), [
    padding("horizontal", 24),
    padding("vertical", 8),
], [
    node("LIGHT Label", text("LIGHT"), [
        font(size=9, weight="semibold", design="monospaced"),
        fg(dim_white),
    ]),
    node("LM Bar", zstack(), [
        frame(None, 32),
        glass_config("regular", warm_orange, 0.15, False, "capsule"),
    ], [
        node("LM Ticks", hstack(0, "center"), [
            padding("horizontal", 20),
        ], tick_children),
        # Red center indicator
        node("Indicator", rectangle, [
            frame(2, 14),
            fg(red_c),
            corner_radius(1),
        ]),
    ]),
])


# ---- CONTROLS ROW ----

photo_lib = node("Photo Lib", image("photo.on.rectangle.angled"), [
    font(size=17, weight="medium"),
    fg(dim_white),
    frame(40, 40),
    glass_config("regular", None, 0.15, True, "roundedRectangle"),
])

film_sim = node("Film Sim", hstack(4, "center"), [
    padding("horizontal", 14),
    padding("vertical", 8),
    glass_config("regular", warm_orange, 0.1, True, "capsule"),
], [
    node("Film Name", text("Superia"), [
        font(size=14, weight="semibold"),
        fg(white),
    ]),
    node("Chevron", image("chevron.down"), [
        font(size=10, weight="bold"),
        fg(dim_white),
    ]),
])

iso_btn = node("ISO", hstack(3, "center"), [
    padding("horizontal", 12),
    padding("vertical", 8),
    glass_config("regular", None, 0.15, True, "capsule"),
], [
    node("ISO Lbl", text("ISO"), [
        font(size=11, weight="medium", design="monospaced"),
        fg(light_gray),
    ]),
    node("ISO Val", text("AUTO"), [
        font(size=13, weight="semibold"),
        fg(white),
    ]),
])

ss_btn = node("SS", hstack(3, "center"), [
    padding("horizontal", 12),
    padding("vertical", 8),
    glass_config("regular", None, 0.15, True, "capsule"),
], [
    node("SS Lbl", text("SS"), [
        font(size=11, weight="medium", design="monospaced"),
        fg(light_gray),
    ]),
    node("SS Val", text("AUTO"), [
        font(size=13, weight="semibold"),
        fg(white),
    ]),
])

controls_row = node("Controls Row", hstack(10, "center"), [
    padding("horizontal", 16),
    padding("vertical", 4),
], [
    photo_lib,
    film_sim,
    node("CSp", spacer()),
    iso_btn,
    ss_btn,
])


# ---- BOTTOM BAR ----

thumbnail = node("Thumbnail", zstack(), [
    frame(52, 52),
], [
    node("Thumb BG", circle_p, [
        fg(mid_gray),
    ]),
    node("Thumb Icon", image("photo.fill"), [
        font(size=18),
        fg(dim_white),
    ]),
])

shutter = node("Shutter", zstack(), [
    frame(72, 72),
], [
    # Outer glass ring
    node("Ring", circle_p, [
        fg(custom(0, 0, 0, 0.01)),
        overlay_border("circle", warm_orange, 3),
        glass_config("regular", warm_orange, 0.2, True, "circle"),
    ]),
    # Inner solid fill
    node("Fill", circle_p, [
        frame(58, 58),
        fg(warm_orange),
    ]),
])

zoom_btn = node("Zoom", text("1x"), [
    font(size=15, weight="bold", design="monospaced"),
    fg(white),
    frame(44, 44),
    glass_config("regular", None, 0.2, True, "circle"),
])

bottom_bar = node("Bottom Bar", hstack(0, "center"), [
    padding("horizontal", 32),
    padding("vertical", 16),
], [
    thumbnail,
    node("BSp1", spacer()),
    shutter,
    node("BSp2", spacer()),
    zoom_btn,
])


# ---- ROOT ----

root = node("Root", zstack(), [
    bg(black),
], [
    node("Main Layout", vstack(0, "center"), [], [
        top_bar,
        viewfinder,
        node("Sp1", spacer(12)),
        light_meter,
        node("Sp2", spacer(8)),
        controls_row,
        node("Sp3", spacer()),
        bottom_bar,
    ]),
])


# ============================================================
#  ASSEMBLE DOCUMENT
# ============================================================

page = {
    "id": uid(),
    "name": "Camera",
    "deviceFrame": "iPhone16Pro",
    "rootElement": root,
    "animationTimeline": {"tracks": []},
    "isDarkMode": True,
}

doc = {
    "pages": [page],
    "tokens": {
        "spacingScale": [4, 8, 12, 16, 20, 24, 32, 40, 48],
        "cornerRadii": [4, 8, 12, 16, 20, 24],
        "accentColor": warm_orange,
        "backgroundColor": black,
        "textColor": white,
    },
    "exportConfig": {
        "projectName": "CameraApp",
        "bundleIdentifier": "com.example.cameraapp",
        "deploymentTarget": "26.0",
        "organizationName": "",
    },
}

# ============================================================
#  SAVE
# ============================================================

out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Documents/CameraApp.iosdesign")
with open(out_path, "w") as f:
    json.dump(doc, f, indent=2)
print(f"Saved to {out_path}")
