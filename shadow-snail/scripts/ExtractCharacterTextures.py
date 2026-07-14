import os

NAMES = [
    "3d卡通外星人模型_basecolor.jpg",
    "3d+模型内裤_basecolor.jpg",
    "紫色棒球帽3d模型_basecolor.jpg",
    "紫色羽绒背心3d模型_basecolor.jpg",
]

FBX_PATH = os.path.join(
    os.path.dirname(__file__),
    "..",
    "assets",
    "characters",
    "default",
    "model",
    "character_body.fbx",
)
OUT_DIRS = [
    os.path.join(os.path.dirname(__file__), "..", "assets", "characters", "default", "model"),
    os.path.join(os.path.dirname(__file__), "..", "assets", "characters", "default", "animations"),
]


def extract_first_jpeg(data: bytes) -> bytes:
    start = data.find(b"\xff\xd8\xff")
    if start == -1:
        raise RuntimeError("No JPEG found in FBX")
    end = data.find(b"\xff\xd9", start)
    if end == -1:
        raise RuntimeError("Incomplete JPEG in FBX")
    return data[start : end + 2]


def main() -> None:
    fbx_abs = os.path.abspath(FBX_PATH)
    blob = extract_first_jpeg(open(fbx_abs, "rb").read())
    for out_dir in OUT_DIRS:
        out_abs = os.path.abspath(out_dir)
        os.makedirs(out_abs, exist_ok=True)
        for name in NAMES:
            target = os.path.join(out_abs, name)
            with open(target, "wb") as handle:
                handle.write(blob)
            print(f"wrote {target} ({len(blob)} bytes)")


if __name__ == "__main__":
    main()
