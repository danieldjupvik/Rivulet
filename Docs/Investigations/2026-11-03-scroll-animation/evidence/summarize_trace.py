import argparse
import json
from pathlib import Path
import xml.etree.ElementTree as ET


def read_rows(path):
    document = ET.parse(path)
    ids = {element.get("id"): element for element in document.iter() if element.get("id")}

    def resolve(element):
        return ids[element.get("ref")] if element.get("ref") else element

    return ([list(map(resolve, row)) for row in document.iter("row")], resolve)


def summarize(directory):
    rows, _ = read_rows(directory / "latest-os-signpost.xml")
    events = set()
    for row in rows:
        if len(row) >= 12:
            events.add((float(row[0].text) / 1e9, row[3].text, row[5].text,
                        row[6].text, row[11].get("fmt", "")))
    pending = {}
    intervals = []
    for time, kind, identifier, name, _ in sorted(events):
        key = (name, identifier)
        if kind == "Begin":
            pending[key] = time
        elif kind == "End" and key in pending:
            intervals.append((pending.pop(key), time, name))

    rows, _ = read_rows(directory / "latest-hitches.xml")
    hitches = [(float(row[0].text) / 1e9, float(row[1].text) / 1e6) for row in rows]
    rows, resolve = read_rows(directory / "latest-time-profile.xml")
    samples = []
    for row in rows:
        if "Main Thread" in row[1].get("fmt", ""):
            samples.append((float(row[0].text) / 1e9,
                            [resolve(frame).get("name", "") for frame in row[6]]))
    windows = []
    for start, end in [(10, 25), (36, 51)]:
        selected = [names for time, names in samples if start <= time < end]
        windows.append({
            "start_seconds": start,
            "end_seconds": end,
            "hitches": sum(start <= time < end for time, _ in hitches),
            "cell_prepare_intervals": sum(start <= a < end and name == "CellPrepare"
                                          for a, _, name in intervals),
            "image_decode_intervals": sum(start <= a < end and name == "ImageDecode"
                                          for a, _, name in intervals),
            "main_thread_samples": len(selected),
            "shelf_configure_samples": sum(any("ShelfRowCell.configure" in name for name in names)
                                           for names in selected),
        })
    return {
        "hitches": len(hitches),
        "hitch_duration_ms": round(sum(duration for _, duration in hitches), 3),
        "max_scroll_step_ms": round(max((b - a) * 1000 for a, b, name in intervals
                                        if name == "ScrollStep"), 3),
        "windows": windows,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Summarize the exported scroll signpost trace.")
    parser.add_argument("directory", type=Path, help="Directory containing the three latest-*.xml exports")
    args = parser.parse_args()
    print(json.dumps(summarize(args.directory), indent=2))
