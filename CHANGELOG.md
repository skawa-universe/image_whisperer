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
