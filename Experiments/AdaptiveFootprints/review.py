"""Read the two frozen Altis outputs; write experiment-only review artifacts.
Uses Python stdlib. Install Pillow only if a PNG preview is wanted as well as SVG.
The SVG is a coordinate plot of generated data, not an edited game screenshot.
"""
import hashlib
import html
import json
import math
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "output" / "altis"
AIRPORT = "altis_airfield_169"
NEAR_BASE = "altis_base_90"


def read_locations(path):
    result = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"_locations pushBack \(createHashMapFromArray (.*)\);", line)
        if match:
            # The serializer writes data arrays with literal SQF path backslashes.
            record = dict(json.loads(match[1].replace("\\", "\\\\")))
            result[record["id"]] = record
    if not result:
        raise ValueError(f"No locations in {path}")
    return result


def shape(site):
    return site.get("footprint", ["circle", site["position"], [site["size"]] * 2, 0])


def area(footprint):
    kind, _, axes, _ = footprint
    return math.pi * axes[0] ** 2 if kind == "circle" else 4 * axes[0] * axes[1]


def perimeter(footprint):
    kind, center, axes, angle = footprint
    c, s = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    if kind == "circle":
        return [(center[0] + axes[0] * math.cos(i * math.tau / 120),
                 center[1] + axes[0] * math.sin(i * math.tau / 120)) for i in range(120)]
    return [(center[0] + u * c + v * s, center[1] - u * s + v * c)
            for u, v in [(-axes[0], -axes[1]), (axes[0], -axes[1]),
                         (axes[0], axes[1]), (-axes[0], axes[1])]]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    baseline = read_locations(ROOT / "baseline" / "locations.sqf")
    adaptive = read_locations(OUT / "locations.sqf")
    common = sorted(baseline.keys() & adaptive.keys())
    fields = ("type", "types", "components", "objectCount", "models", "typeCounts",
              "militaryBuildings", "militaryBuildingCounts")
    changes = [{"id": key, "changes": {
        field: {"baseline": baseline[key].get(field), "adaptive": adaptive[key].get(field)}
        for field in fields if baseline[key].get(field) != adaptive[key].get(field)}}
        for key in common if any(baseline[key].get(f) != adaptive[key].get(f) for f in fields)]
    old_airport, new_airport = baseline[AIRPORT], adaptive[AIRPORT]
    old_area, new_area = area(shape(old_airport)), area(shape(new_airport))
    source_summary = json.loads((ROOT / "baseline" / "summary.json").read_text())
    summary = {
        "world": "Altis", "status": "isolated unreviewed experiment",
        "index_version": 6, "variant": "adaptive-footprints-v1",
        "scanned_objects": source_summary["scanned_objects"],
        "locations": len(adaptive),
        "categories": dict(sorted(Counter(x["type"] for x in adaptive.values()).items())),
        "shapes": dict(sorted(Counter(shape(x)[0] for x in adaptive.values()).items())),
        "secondary_role_sites": {role: sum(role in x["types"] for x in adaptive.values()) for role in ["air", "heli", "radar"]},
        "added_ids": sorted(adaptive.keys() - baseline.keys()),
        "removed_ids": sorted(baseline.keys() - adaptive.keys()),
        "changed_semantic_records": len(changes),
        "unchanged_for_all_common_sites": {field: all(adaptive[k].get(field) == baseline[k].get(field) for k in common)
            for field in ["type", "types", "components", "militaryBuildings", "militaryBuildingCounts"]},
        "main_airport": {
            "id": AIRPORT, "baseline_radius_m": old_airport["size"],
            "footprint": shape(new_airport),
            "dimensions_m": [2 * v for v in shape(new_airport)[2]],
            "baseline_area_m2": old_area, "adaptive_area_m2": new_area,
            "area_reduction_percent": 100 * (1 - new_area / old_area),
            "objects_before": old_airport["objectCount"], "objects_after": new_airport["objectCount"]},
        "nearby_base": {"id": NEAR_BASE, "objects_before": baseline[NEAR_BASE]["objectCount"],
            "objects_after": adaptive[NEAR_BASE]["objectCount"],
            "explanation": "Only runway air-role annotations change; military buildings, core components and roles remain unchanged."},
        "sha256": {name: digest(path) for name, path in {
            "baseline_locations": ROOT / "baseline" / "locations.sqf",
            "adaptive_locations": OUT / "locations.sqf",
            "adaptive_settings": ROOT / "settings.sqf",
            "inventory": ROOT / ".." / ".." / "Locations" / "Indexing" / "output" / "altis" / "objects.sqf"}.items()}}
    (OUT / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    comparison = {"semantic_changes": changes, "footprints": [
        {"id": k, "baseline": shape(baseline[k]), "adaptive": shape(adaptive[k]),
         "baseline_area_m2": area(shape(baseline[k])), "adaptive_area_m2": area(shape(adaptive[k]))} for k in common]}
    (OUT / "comparison.json").write_text(json.dumps(comparison, indent=2) + "\n", encoding="utf-8")
    plot(baseline, adaptive, summary)
    print(json.dumps({"locations": summary["locations"], "shapes": summary["shapes"],
                      "airport_area_reduction_percent": summary["main_airport"]["area_reduction_percent"],
                      "changed_semantic_records": len(changes)}, indent=2))


def plot(baseline, adaptive, summary):
    # Exactly the same coordinate window and metres-per-pixel in both panels.
    width, height = 1420, 960
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">']
    try:
        from PIL import Image, ImageDraw, ImageFont
        image = Image.new("RGB", (width, height), "#f7f8fa")
        draw = ImageDraw.Draw(image)
        def font(size):
            return ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", size)
    except ImportError:
        image = draw = None

    def box(bounds, fill, stroke=None):
        x0, y0, x1, y1 = bounds
        svg.append(f'<rect x="{x0}" y="{y0}" width="{x1-x0}" height="{y1-y0}" fill="{fill}" stroke="{stroke or fill}"/>')
        if draw: draw.rectangle(bounds, fill=fill, outline=stroke)

    def text(x, y, value, size=17, color="#263448"):
        svg.append(f'<text x="{x}" y="{y+size}" fill="{color}" font-family="Segoe UI, sans-serif" font-size="{size}">{html.escape(value)}</text>')
        if draw: draw.text((x, y), value, font=font(size), fill=color)

    def line(points, color, thickness=1, closed=False):
        coordinates = " ".join(f"{x:.2f},{y:.2f}" for x,y in points)
        tag = "polygon" if closed else "polyline"
        svg.append(f'<{tag} points="{coordinates}" fill="none" stroke="{color}" stroke-width="{thickness}"/>')
        if draw: draw.line(points + ([points[0]] if closed else []), fill=color, width=thickness, joint="curve")

    box((0,0,width,height), "#f7f8fa")
    text(40,24,"Altis airport | adaptive footprint experiment",30)
    text(40,68,"Generated coordinates at the same scale. Coloured outlines are site boundaries; dots identify nearby sites.",18)
    text(40,98,"This is a geometry comparison without a terrain basemap. Review the in-game overlay before merging.",17,"#606b7a")
    scale, x_min, y_min = 0.234, 13450, 15000
    panel_top, panel_height, panel_width = 211, 702, 655.2
    neighbours = [
        ("altis_town_3905", "Settlement", -80, -29),
        ("altis_radiotower_22", "Radio", -54, -23),
        ("altis_fuel_52", "Fuel", -48, 0),
        ("altis_power_386", "Power", 11, -12),
        ("altis_port_252", "Port", 11, 0),
        ("altis_base_132", "North base", 10, -22),
    ]
    for panel, (sites, title) in enumerate([(baseline,"Current index: circles"),(adaptive,"Experiment: adaptive footprints")]):
        left = 35 + panel * 695
        text(left,145,title,24)
        f = shape(sites[AIRPORT])
        value = (f"{f[2][0]:,.0f} m airport radius" if f[0] == "circle" else
                 f"{2*f[2][0]:,.0f} x {2*f[2][1]:,.0f} m airport rectangle | {f[3]:.1f} deg")
        text(left,180,value,17,"#566477")
        box((left,panel_top,left+panel_width,panel_top+panel_height),"#ffffff","#d9e0e8")
        def project(point):
            return left + (point[0]-x_min)*scale, panel_top + panel_height - (point[1]-y_min)*scale
        for x in range(13500,16251,500):
            line([project((x,15000)),project((x,18000))],"#e6ebf1")
        for y in range(15000,18001,500):
            line([project((13450,y)),project((16250,y))],"#e6ebf1")
        for key, color in [(AIRPORT,"#b52d35"),(NEAR_BASE,"#7051ad")]:
            line([project(p) for p in perimeter(shape(sites[key]))],color,3,True)
        for key,label,dx,dy in neighbours:
            x,y = project(sites[key]["position"])
            box((x-3,y-3,x+3,y+3),"#277665")
            text(x+dx,y+dy,label,16,"#236757")
        x,y = project(sites[NEAR_BASE]["position"])
        text(x-70,y+45,"Nearby base",17,"#7051ad")
        text(x-70,y+68,f"{int(sites[NEAR_BASE]['objectCount'])} objects",16,"#7051ad")
        text(left+18,panel_top+18,"N",17)
        line([(left+26,panel_top+66),(left+26,panel_top+46)],"#263448",2)
        line([(left+21,panel_top+51),(left+26,panel_top+46),(left+31,panel_top+51)],"#263448",2)
        line([(left+20,panel_top+panel_height-28),(left+20+500*scale,panel_top+panel_height-28)],"#263448",3)
        text(left+20,panel_top+panel_height-58,"500 m",16)
    airport = summary["main_airport"]
    before = int(airport["objects_before"])
    after = int(airport["objects_after"])
    text(40,924,f"Airport: {airport['area_reduction_percent']:.0f}% less covered area. Objects: {before:,} -> {after:,}. "
         "Nearby site identities and ownership are compared in summary.json.",18)
    svg.append("</svg>")
    (OUT / "airport-comparison.svg").write_text("\n".join(svg),encoding="utf-8")
    if image:
        image.save(OUT / "airport-comparison.png")


if __name__ == "__main__":
    main()
