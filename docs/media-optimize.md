# Media optimization pilot

`lib/bootwitch/media_optimize.py` is a local, opt-in derivative maker. It does
not edit the original, rewrite site references, delete assets, or deploy.

```sh
python3 lib/bootwitch/media_optimize.py source.mov derivatives/source.mp4 --dry-run
python3 lib/bootwitch/media_optimize.py source.mov derivatives/source.mp4
python3 lib/bootwitch/media_optimize.py source.png derivatives/source.webp
```

Create the output directory yourself first. The output must not exist. Results
are JSON with `created`, `skipped-not-smaller`, or `dry-run` status and measured
byte counts. A skipped conversion does not leave a derivative.

Images: BMP, JPEG, or PNG to WebP at quality 78, using Pillow with WebP support.
Transparency is preserved for PNGs with an alpha channel or transparency index.
Animated images are rejected. Videos: AVI, MKV, MOV, MP4, or WebM to H.264/AAC
MP4 using `ffmpeg` and `ffprobe`; video settings are CRF 28, medium preset,
`yuv420p`, AAC 128 kb/s, and faststart. Video conversion needs an `ffmpeg`
build containing `libx264` and `aac`. A missing tool or codec fails without
publishing a derivative. Each conversion is limited to five minutes; the
temporary output is created beside the final destination and removed after
success, skip, or ordinary failure.

Video output selects the first optional audio stream only, omitting extra audio
tracks such as commentary. It drops source format/stream metadata and chapters,
including potential author or location tags. Image input is capped at 50 million
pixels and Pillow
decompression-bomb warnings are treated as failures. The five-minute timeout
applies to external video tools, not Pillow's in-process work.

This is a candidate generator, not an automatic quality decision. Review
playback, image detail, audio, color, captions, and browser compatibility before
changing a deployment to use a derivative. Size savings are not guaranteed.
Several portfolio videos are already compact H.264 MP4 files; duplicate
deployment inputs may matter more than another encode. Do not delete or
deduplicate those assets until Rowan verifies their references.

Safety boundary: source and destination must be regular, non-symlink paths;
`..` path components, same-file output, and existing output are refused. A
private temporary directory holds the candidate. The module probes and fully
decodes video, or loads image pixels, before publishing through an exclusive
hard link so an output appearing mid-conversion is never overwritten. It checks
the source's inode, size, and modification time before publication. These are
cooperative local safeguards, not a race-proof boundary against a hostile
process replacing files during checks, and not a resource sandbox for
untrusted media. Do not pass attacker-controlled paths or files to this pilot.
