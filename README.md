# image_whisperer

Rotate and resize images before uploading as necessary.

Rotates the image according to the EXIF information so the image will look
normal after reencoding or when they are displayed on a canvas.

Also images can be resized by specifying maximum width/height/pixels
(as in maximum number of megapixels, but without the mega prefix).

# Usage

Two types of images are used and supported: `BlobImage` and `CanvasImage`.
`BlobImage` contains a `dart:html` `Blob` with the image data (image file
contents), `CanvasImage` contains a `CanvasElement` with the image itself.

```dart
ImageProcessingPipeline pipeline = new ImageProcessingPipeline();
// The current version of the pipeline returns a BlobImage no matter what.
// Sets the output format to JPEG and the quality to 75.
pipeline.requireBlob("image/jpeg", quality: 75);
// The result should contain no more than 4096 pixels (which makes it quite small)
pipeline.maxPixels = 4096;
// Let's assume there's a `<input type="file"/>` field in the DOM and happens to
// have a nonempty value
FileUploadInputElement input = querySelector("input[type=file]");
File file = input.files.first;
BlobImage image = new BlobImage(file, name: file.name);
pipeline.process(image).then((BaseImage result) {
  // result is a BlobImage, and will always be with the default settings,
  // but I may change the API so we can receive a CanvasImage.
  Blob blob = (result as BlobImage).blob;

  // start a "download", so the image is saved

  String url;
  try {
    url = Url.createObjectUrl(blob);
    AnchorElement a = new AnchorElement();
    a.download = "${result.name}.resized.jpg";
    a.href = url;
    a.click();
  } finally {
    if (url != null) Url.revokeObjectUrl(url);
  }
});
```

## Getting Started

Check out the https://github.com/skawa-universe/no_exif/ project
for an example and details on how to deal with the pipeline and
`BaseImage` objects.
