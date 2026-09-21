#!/usr/bin/env python3
"""Create a smaller, verified web derivative without changing its source."""

import argparse
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import warnings


IMAGE_INPUTS = {".bmp", ".jpg", ".jpeg", ".png"}
VIDEO_INPUTS = {".avi", ".mkv", ".mov", ".mp4", ".webm"}
TIMEOUT_SECONDS = 300
MAX_IMAGE_PIXELS = 50_000_000


class MediaError(ValueError):
    """An input, dependency, or conversion failed safely."""


def _checked_path(raw, *, must_exist):
    path = Path(raw).expanduser()
    if ".." in path.parts:
        raise MediaError("parent traversal is not allowed")
    path = Path(os.path.abspath(path))
    for part in (path, *path.parents):
        if part.is_symlink():
            raise MediaError(f"symlink path is not allowed: {part}")
    if must_exist:
        if not path.is_file() or not stat.S_ISREG(path.stat().st_mode):
            raise MediaError(f"source must be a regular file: {path}")
    elif not path.parent.is_dir():
        raise MediaError(f"output parent must already exist: {path.parent}")
    return path


def _tools():
    ffmpeg, ffprobe = shutil.which("ffmpeg"), shutil.which("ffprobe")
    if not ffmpeg or not ffprobe:
        raise MediaError("ffmpeg and ffprobe are required; install both before converting")
    return ffmpeg, ffprobe


def _pillow():
    try:
        from PIL import Image, features
    except ImportError as error:
        raise MediaError("Pillow with WebP support is required for image conversion") from error
    if not features.check("webp"):
        raise MediaError("Pillow was built without WebP support")
    return Image


def _probe(ffprobe, path, media_type):
    try:
        result = subprocess.run(
            [ffprobe, "-v", "error", "-show_entries", "stream=codec_type",
             "-of", "json", str(path)], capture_output=True, text=True,
            timeout=TIMEOUT_SECONDS, check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise MediaError(f"could not probe media: {error}") from error
    if result.returncode:
        raise MediaError("media probe rejected the file")
    try:
        streams = json.loads(result.stdout)["streams"]
    except (ValueError, KeyError, TypeError) as error:
        raise MediaError("media probe returned an invalid result") from error
    if not any(stream.get("codec_type") == "video" for stream in streams):
        raise MediaError(f"{media_type} has no decodable image/video stream")


def optimize(source, output, *, dry_run=False):
    """Return a JSON-ready result; never overwrite existing output or source."""
    src = _checked_path(source, must_exist=True)
    dst = _checked_path(output, must_exist=False)
    if src == dst or (dst.exists() and os.path.samefile(src, dst)):
        raise MediaError("output must be separate from source")
    if dst.exists() or dst.is_symlink():
        raise MediaError("output already exists; refusing to overwrite")
    suffix = src.suffix.lower()
    if suffix in IMAGE_INPUTS:
        kind, expected = "image", ".webp"
    elif suffix in VIDEO_INPUTS:
        kind, expected = "video", ".mp4"
    else:
        raise MediaError(f"unsupported input extension: {suffix or '(none)'}")
    if dst.suffix.lower() != expected:
        raise MediaError(f"{kind} output must use {expected}")
    before = src.stat()
    if dry_run:
        return {"status": "dry-run", "kind": kind, "source": str(src),
                "output": str(dst), "source_bytes": before.st_size}
    if kind == "image":
        Image = _pillow()
    else:
        ffmpeg, ffprobe = _tools()
        _probe(ffprobe, src, kind)
    stage = Path(tempfile.mkdtemp(prefix=".bootwitch-media-", dir=dst.parent))
    derivative = stage / ("derivative" + expected)
    try:
        if kind == "image":
            try:
                with warnings.catch_warnings():
                    warnings.simplefilter("error", Image.DecompressionBombWarning)
                    with Image.open(src) as original:
                        if original.width * original.height > MAX_IMAGE_PIXELS:
                            raise MediaError("image exceeds 50 million pixel limit")
                        original.load()
                        if getattr(original, "n_frames", 1) != 1:
                            raise MediaError("animated images are not supported")
                        color_mode = "RGBA" if "A" in original.getbands() or "transparency" in original.info else "RGB"
                        original.convert(color_mode).save(derivative, "WEBP", quality=78)
            except (OSError, ValueError, Image.DecompressionBombWarning,
                    Image.DecompressionBombError) as error:
                raise MediaError(f"image conversion failed: {error}") from error
            try:
                with Image.open(derivative) as decoded_image:
                    decoded_image.load()
                    if decoded_image.format != "WEBP":
                        raise MediaError("derivative is not WebP")
            except (OSError, ValueError) as error:
                raise MediaError(f"image derivative failed validation: {error}") from error
        else:
            encoding = ["-map", "0:v:0", "-map", "0:a:0?", "-c:v", "libx264",
                        "-preset", "medium", "-crf", "28", "-pix_fmt", "yuv420p",
                        "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart"]
            encoding.extend(["-map_metadata", "-1", "-map_metadata:s:v:0", "-1",
                             "-map_metadata:s:a:0", "-1", "-map_chapters", "-1"])
            try:
                result = subprocess.run(
                    [ffmpeg, "-hide_banner", "-loglevel", "error", "-nostdin", "-n",
                     "-i", str(src), *encoding, str(derivative)],
                    capture_output=True, text=True, timeout=TIMEOUT_SECONDS, check=False,
                )
            except (OSError, subprocess.TimeoutExpired) as error:
                raise MediaError(f"media conversion failed: {error}") from error
            if result.returncode:
                raise MediaError(f"media conversion failed: {result.stderr.strip()[:500]}")
        if not derivative.is_file() or derivative.stat().st_size == 0:
            raise MediaError("encoder produced no derivative")
        if kind == "video":
            _probe(ffprobe, derivative, kind)
            decoded = subprocess.run(
                [ffmpeg, "-v", "error", "-xerror", "-i", str(derivative), "-f", "null", "-"],
                capture_output=True, text=True, timeout=TIMEOUT_SECONDS, check=False,
            )
            if decoded.returncode:
                raise MediaError("derivative failed full decode")
        after = src.stat()
        if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (
                after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
            raise MediaError("source changed during conversion")
        output_bytes = derivative.stat().st_size
        if output_bytes >= before.st_size:
            return {"status": "skipped-not-smaller", "kind": kind,
                    "source": str(src), "output": str(dst),
                    "source_bytes": before.st_size, "candidate_bytes": output_bytes}
        # A hard link fails if a destination appeared during conversion.
        try:
            os.link(derivative, dst, follow_symlinks=False)
        except FileExistsError as error:
            raise MediaError("output appeared during conversion; refusing overwrite") from error
        return {"status": "created", "kind": kind, "source": str(src),
                "output": str(dst), "source_bytes": before.st_size,
                "output_bytes": output_bytes, "saved_bytes": before.st_size - output_bytes}
    finally:
        derivative.unlink(missing_ok=True)
        stage.rmdir()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source")
    parser.add_argument("output")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    try:
        print(json.dumps(optimize(args.source, args.output, dry_run=args.dry_run), indent=2))
        return 0
    except (MediaError, OSError, subprocess.TimeoutExpired) as error:
        print(f"bootwitch-media: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
