"""Safety and real-encoder tests for the opt-in media derivative module."""

import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock


MODULE = Path(__file__).resolve().parents[1] / "lib/bootwitch/media_optimize.py"
SPEC = importlib.util.spec_from_file_location("media_optimize", MODULE)
media = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(media)


class MediaOptimizeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=Path(__file__).parent)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "source.bmp"
        width = height = 64
        pixels = (b"\x30\x80\xc0" * width) * height
        size = 54 + len(pixels)
        header = (b"BM" + size.to_bytes(4, "little") + b"\0" * 4
                  + (54).to_bytes(4, "little") + (40).to_bytes(4, "little")
                  + width.to_bytes(4, "little") + height.to_bytes(4, "little")
                  + (1).to_bytes(2, "little") + (24).to_bytes(2, "little")
                  + b"\0" * 24)
        self.source.write_bytes(header + pixels)
        self.output = self.root / "out.webp"

    def test_dry_run_does_not_require_encoder_or_write(self):
        result = media.optimize(self.source, self.output, dry_run=True)
        self.assertEqual(result["status"], "dry-run")
        self.assertFalse(self.output.exists())

    def test_rejects_bad_paths_and_existing_output(self):
        with self.assertRaisesRegex(media.MediaError, "separate"):
            media.optimize(self.source, self.source)
        with self.assertRaisesRegex(media.MediaError, "traversal"):
            media.optimize(self.source, self.root / "sub" / ".." / "out.webp")
        linked = self.root / "linked.bmp"
        linked.symlink_to(self.source)
        with self.assertRaisesRegex(media.MediaError, "symlink"):
            media.optimize(linked, self.output)
        destination_link = self.root / "output-link.webp"
        destination_link.symlink_to(self.source)
        with self.assertRaisesRegex(media.MediaError, "symlink"):
            media.optimize(self.source, destination_link)
        self.output.write_bytes(b"user-owned")
        with self.assertRaisesRegex(media.MediaError, "already exists"):
            media.optimize(self.source, self.output)
        self.assertEqual(self.output.read_bytes(), b"user-owned")

    def test_unsupported_format_and_missing_tool(self):
        bad = self.root / "bad.txt"
        bad.write_bytes(b"hello")
        with self.assertRaisesRegex(media.MediaError, "unsupported"):
            media.optimize(bad, self.output)
        original_tools = media._pillow
        try:
            media._pillow = lambda: (_ for _ in ()).throw(media.MediaError("tools missing"))
            with self.assertRaisesRegex(media.MediaError, "tools missing"):
                media.optimize(self.source, self.output)
        finally:
            media._pillow = original_tools
        self.assertFalse(self.output.exists())

    @unittest.skipUnless(importlib.util.find_spec("PIL"), "Pillow required")
    def test_image_pixel_limit_rejects_before_decode(self):
        oversized = bytearray(self.source.read_bytes())
        oversized[18:22] = (100_000).to_bytes(4, "little")
        oversized[22:26] = (100_000).to_bytes(4, "little")
        self.source.write_bytes(oversized)
        with self.assertRaisesRegex(media.MediaError, "pixel|conversion failed"):
            media.optimize(self.source, self.output)
        self.assertFalse(self.output.exists())
        self.assertEqual(list(self.root.glob(".bootwitch-media-*")), [])

    @unittest.skipUnless(importlib.util.find_spec("PIL"), "Pillow required")
    def test_transparent_png_preserves_alpha(self):
        from PIL import Image
        transparent = self.root / "transparent.png"
        picture = Image.new("RGBA", (128, 128), (20, 90, 140, 0))
        picture.save(transparent)
        # The compressed PNG can be smaller than WebP; pad valid PNG with
        # ancillary trailing bytes so this test exercises publication.
        with transparent.open("ab") as stream:
            stream.write(b"padding" * 2000)
        result = media.optimize(transparent, self.output)
        self.assertEqual(result["status"], "created")
        with Image.open(self.output) as derivative:
            self.assertIn("A", derivative.getbands())
            self.assertEqual(derivative.getpixel((0, 0))[3], 0)

    @unittest.skipUnless(importlib.util.find_spec("PIL"), "Pillow required")
    def test_image_derivative_is_smaller_and_source_unchanged(self):
        original = self.source.read_bytes()
        result = media.optimize(self.source, self.output)
        self.assertEqual(result["status"], "created")
        self.assertLess(result["output_bytes"], result["source_bytes"])
        self.assertEqual(self.source.read_bytes(), original)
        self.assertEqual(list(self.root.glob(".bootwitch-media-*")), [])

    @unittest.skipUnless(importlib.util.find_spec("PIL"), "Pillow required")
    def test_invalid_media_leaves_no_output_or_temp(self):
        self.source.write_bytes(b"not a bmp")
        with self.assertRaisesRegex(media.MediaError, "conversion failed"):
            media.optimize(self.source, self.output)
        self.assertFalse(self.output.exists())
        self.assertEqual(list(self.root.glob(".bootwitch-media-*")), [])

    @unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"), "ffmpeg required")
    def test_video_derivative_from_lossless_fixture(self):
        source = self.root / "video.mkv"
        output = self.root / "video.mp4"
        subprocess.run([shutil.which("ffmpeg"), "-v", "error", "-f", "lavfi",
                        "-i", "testsrc2=size=128x128:rate=12:duration=2",
                        "-f", "lavfi", "-i", "sine=frequency=440:duration=2",
                        "-f", "lavfi", "-i", "sine=frequency=880:duration=2",
                        "-map", "0:v:0", "-map", "1:a:0", "-map", "2:a:0",
                        "-c:v", "ffv1", "-c:a", "pcm_s16le",
                        "-metadata", "artist=Private Author",
                        "-metadata:s:v:0", "title=Private Video Tag",
                        "-metadata:s:a:1", "title=Private Commentary Track",
                        str(source)], check=True)
        source_metadata = subprocess.run([shutil.which("ffprobe"), "-v", "error",
                                          "-show_entries", "format_tags:stream_tags",
                                          "-of", "json", str(source)],
                                         capture_output=True, text=True, check=True)
        self.assertIn("Private Author", source_metadata.stdout)
        self.assertIn("Private Video Tag", source_metadata.stdout)
        self.assertIn("Private Commentary Track", source_metadata.stdout)
        original = source.read_bytes()
        result = media.optimize(source, output)
        self.assertEqual(result["status"], "created")
        self.assertEqual(source.read_bytes(), original)
        self.assertLess(output.stat().st_size, source.stat().st_size)
        metadata = subprocess.run([shutil.which("ffprobe"), "-v", "error",
                                   "-show_entries", "format_tags:stream=codec_type:stream_tags",
                                   "-of", "json", str(output)],
                                  capture_output=True, text=True, check=True)
        self.assertNotIn("Private Author", metadata.stdout)
        self.assertNotIn("Private Video Tag", metadata.stdout)
        self.assertNotIn("Private Commentary Track", metadata.stdout)
        streams = json.loads(metadata.stdout)["streams"]
        self.assertEqual(sum(stream["codec_type"] == "audio" for stream in streams), 1)

    @unittest.skipUnless(importlib.util.find_spec("PIL"), "Pillow required")
    def test_larger_candidate_is_skipped(self):
        from PIL import Image
        original_save = Image.Image.save

        def padded_save(image, target, *args, **kwargs):
            original_save(image, target, *args, **kwargs)
            with open(target, "ab") as derivative:
                derivative.write(b"padding" * 3000)

        with mock.patch.object(Image.Image, "save", padded_save):
            result = media.optimize(self.source, self.output)
        self.assertEqual(result["status"], "skipped-not-smaller")
        self.assertFalse(self.output.exists())
        self.assertEqual(list(self.root.glob(".bootwitch-media-*")), [])


if __name__ == "__main__":
    unittest.main()
