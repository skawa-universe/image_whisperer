# 0.11.0

- the library is updated to support and require Dart 2.2

# 0.10.0

- bumped `exifdart` version
- the library now requires Dart 2

# 0.9.4

- bumped `exifdart` version

# 0.9.3+1

- Added polyfill to fix IE11's lack of support of quality parameters in
  `HTMLCanvasElement.toBlob`

# 0.9.3

- The pipeline can skip encoding the image to file and return with a `CanvasImage`
  (or a `BlobImage` if no adjustment was needed at all)

# 0.9.2

- Added wrappers for `Url.createObjectUrl` and `Url.revokeObjectUrl`
  in `BlobImage`
- Made a function private that was previously public by accident

# 0.9.1+2

- Fixed handling of files without EXIF

# 0.9.1+1

Maintenance release.

# 0.9.1

- Added the option to use the not really recommended native scaler: it applies no
  filters, the photos will look ugly. But it's fast.
