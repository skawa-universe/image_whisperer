import "dart:async";
import "dart:html";
import "dart:math" as math;
import "dart:typed_data";

import "package:exifdart/exifdart.dart";

class ImageLoadError extends Error {
  ImageLoadError(this.event);

  @override
  String toString() => event?.message ?? "Unknown error";

  final ErrorEvent event;
}

Future<CanvasElement> _convertBlobToCanvas(Blob blob) async {
  String url;
  try {
    url = Url.createObjectUrl(blob);
    return await _loadImage(url);
  } finally {
    if (url != null) Url.revokeObjectUrl(url);
  }
}

Future<CanvasElement> _loadImage(String url) {
  Completer<CanvasElement> result = new Completer();
  ImageElement image = new ImageElement();
  image.onLoad.listen((_) {
    CanvasElement canvas = new CanvasElement(
      width: image.naturalWidth,
      height: image.naturalHeight,
    );
    CanvasRenderingContext2D context = canvas.context2D;
    context.drawImage(image, 0, 0);
    result.complete(canvas);
  });
  image.onError.listen((Event event) {
    result.completeError(new ImageLoadError(event is ErrorEvent ? event : null));
  });
  image.src = url;
  return result.future;
}

Future<Blob> _canvasToBlob(CanvasElement canvas, String mimeType, {int quality}) {
  Completer<Blob> result = new Completer();
  if (mimeType != "image/jpeg") quality = null;
  canvas.toBlob(result.complete, mimeType, quality);
  return result.future;
}

abstract class BaseImage {
  BaseImage([this.name]);

  String name;

  FutureOr<CanvasImage> toCanvasImage();
  FutureOr<BlobImage> toBlobImage(String mimeType, {int quality});
}

class BlobImage extends BaseImage {
  BlobImage(this.blob, {String name}) : super(name) {
    if (blob is File && name == null) name = (blob as File).name;
  }

  @override
  FutureOr<BlobImage> toBlobImage(String mimeType, {int quality}) async {
    if (blob.type == mimeType) return this;
    CanvasImage canvasImage = await toCanvasImage();
    return await canvasImage.toBlobImage(mimeType, quality: quality);
  }

  @override
  FutureOr<CanvasImage> toCanvasImage() async {
    return new CanvasImage(await _convertBlobToCanvas(blob), name: name);
  }

  final Blob blob;
}

class CanvasImage extends BaseImage {
  CanvasImage(this.canvas, {String name}) : super(name);

  @override
  FutureOr<CanvasImage> toCanvasImage() => this;

  @override
  FutureOr<BlobImage> toBlobImage(String mimeType, {int quality}) async {
    return new BlobImage(await _canvasToBlob(canvas, mimeType, quality: quality), name: name);
  }

  final CanvasElement canvas;
}

Future<BaseImage> rotateIfNeeded(BaseImage image) async {
  if (image is BlobImage) {
    return readExifFromBlob(image.blob).then((Map<String, dynamic> params) {
      if (params["Orientation"] is! num || params["Orientation"] == 0) return image;
      int o = (params["Orientation"] as num).toInt();
      return new Future.sync(() => image.toCanvasImage()).then((CanvasImage canvasImage) {
        bool flip = o > 4;
        CanvasElement canvas = canvasImage.canvas;
        int width = !flip ? canvas.width : canvas.height;
        int height = flip ? canvas.width : canvas.height;
        CanvasElement backingCanvas = new CanvasElement(
          width: width,
          height: height,
        );

        CanvasRenderingContext2D context = backingCanvas.context2D;
        context.save();
        if (o > 0) {
          Float32List mat = new Float32List(6);
          int x = o <= 4 ? 0 : 1;
          int y = o <= 4 ? 1 : 0;
          double xs = ((o & 3) >> 1) != 0 ? -1.0 : 1.0;
          double ys = (((o - 1) & 3) >> 1) != 0 ? -1.0 : 1.0;
          mat[2 * x] = xs;
          mat[2 * y] = 0.0;
          mat[2 * x + 1] = 0.0;
          mat[2 * y + 1] = ys;
          mat[4] = -width * math.min(0.0, xs);
          mat[5] = -height * math.min(0.0, ys);
          context.transform(mat[0], mat[1], mat[2], mat[3], mat[4], mat[5]);
        }
        context.drawImage(canvas, 0, 0);
        context.restore();
        return new CanvasImage(backingCanvas, name: image.name);
      });
    });
  } else {
    return image;
  }
}

Future<CanvasElement> _scale(CanvasElement input, int targetWidth, int targetHeight,
    {bool enableYielding: false}) async {
  enableYielding ??= false;
  targetWidth ??= 0;
  targetHeight ??= 0;
  int sw = input.width;
  int sh = input.height;
  CanvasElement canvas = new CanvasElement(width: sw, height: sh);
  CanvasRenderingContext2D ctx = canvas.context2D;
  ctx.drawImage(input, 0, 0);
  ImageData sourceImageData = ctx.getImageData(0, 0, sw, sh);
  if (sw == targetWidth && sh == targetHeight) return canvas;
  Uint8ClampedList source = sourceImageData.data;
  ImageData targetImageData = ctx.createImageData(targetWidth, targetHeight);
  Uint8ClampedList target = targetImageData.data;
  Uint32List targetLine = new Uint32List(4 * targetWidth);
  Uint32List sampleCount = new Uint32List(targetWidth);
  int tyc = 0;
  int srcLine = 0;
  int trgLine = 0;
  Stopwatch time = enableYielding ? (new Stopwatch()..start()) : null;
  Duration yieldDuration = enableYielding ? new Duration(milliseconds: 5) : null;
  for (int sy = 0; sy < sh; ++sy) {
    if (time != null && time.elapsedMilliseconds > 10) {
      // yield for a bit
      await new Future.delayed(yieldDuration);
      time.reset();
    }
    int tx = 0;
    int txc = 0;
    for (int sx = 0; sx < sw; ++sx) {
      ++sampleCount[tx];
      for (int c = 0; c < 4; ++c) targetLine[4 * tx + c] += source[srcLine + sx * 4 + c];
      txc += targetWidth;
      if (txc >= sw) {
        txc -= sw;
        ++tx;
      }
    }
    srcLine += sw * 4;
    tyc += targetHeight;
    if (tyc >= sh) {
      for (int tx = 0; tx < targetWidth; ++tx) {
        for (int c = 0; c < 4; ++c) {
          target[trgLine + tx * 4 + c] = targetLine[tx * 4 + c] ~/ sampleCount[tx];
        }
      }

      for (int tx = 0; tx < targetWidth; ++tx) {
        for (int c = 0; c < 4; ++c) {
          targetLine[tx * 4 + c] = 0;
        }
        sampleCount[tx] = 0;
      }

      tyc -= sh;
      trgLine += targetWidth * 4;
    }
  }

  canvas.width = targetWidth;
  canvas.height = targetHeight;
  ctx.clearRect(0, 0, targetWidth, targetHeight);
  ctx.putImageData(targetImageData, 0, 0);

  return canvas;
}

class ImageProcessingPipeline {
  Future<BaseImage> process(BaseImage image) {
    Future<BaseImage> result = new Future.sync(() => image);
    if (applyOrientation ?? true) result = result.then(rotateIfNeeded);
    result = result.then(_resizeIfNeeded).then(_convertIfNeeded);
    return result;
  }

  bool applyOrientation = true;

  void requireBlob(String mimeType, {int quality: 75, bool force: true}) {
    _mimeType = mimeType ?? "image/jpeg";
    _quality = _mimeType == "image/jpeg" ? quality : null;
    _force = force ?? true;
  }

  FutureOr<BaseImage> _convertIfNeeded(BaseImage image) async {
    if (!_force && image is BlobImage) return image;
    if (image is BlobImage && image.blob.type == _mimeType) return image;
    return await image.toBlobImage(_mimeType, quality: _quality);
  }

  String _mimeType = "image/jpeg";
  int _quality = 75;
  bool _force = false;

  FutureOr<BaseImage> _resizeIfNeeded(BaseImage image) async {
    if (maxWidth == null && maxHeight == null && maxPixels == null) return image;
    CanvasImage canvasImage = await image.toCanvasImage();
    CanvasElement canvas = canvasImage.canvas;
    int width = canvas.width;
    int height = canvas.height;
    double scale = 1.0;
    if (maxWidth != null && width * scale > maxWidth) scale = maxWidth / width;
    if (maxHeight != null && height * scale > maxWidth) scale = maxWidth / width;
    if (maxPixels != null && width * height * scale * scale > maxPixels) {
      scale = math.sqrt(maxPixels / (width * height));
    }
    if ((scale - 1.0).abs() < scaleEpsilon) return image;
    if (useNativeScaler ?? false) {
      CanvasElement newCanvas = new CanvasElement(
        width: (width * scale).toInt(),
        height: (height * scale).toInt(),
      );
      newCanvas.context2D
          .drawImageScaled(canvasImage.canvas, 0, 0, newCanvas.width, newCanvas.height);
      canvasImage = new CanvasImage(newCanvas, name: image.name);
    } else {
      canvasImage = new CanvasImage(
          await _scale(canvasImage.canvas, (width * scale).toInt(), (height * scale).toInt()),
          name: image.name);
    }
    return canvasImage;
  }

  bool useNativeScaler = false;

  /// Maximum width of image
  int maxWidth;

  /// Maximum height of image
  int maxHeight;

  /// Maximum number of pixels of image
  int maxPixels;

  set maxMegapixels(int value) => maxPixels = value * 1000000;

  /// Don't scale if it would mean less than 0.1% change in size
  static const double scaleEpsilon = 0.001;
}
