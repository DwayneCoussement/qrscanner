library qrscanner;

import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';

class QRScanner extends StatefulWidget {
  final void Function(String) onQRCodeCallback;
  final void Function(Error) onQRError;

  QRScanner({this.onQRCodeCallback, this.onQRError});

  @override
  State<StatefulWidget> createState() {
    return _QRWidgetState();
  }
}

class _QRWidgetState extends State<QRScanner> {
  CameraController controller;
  BarcodeDetector barcodeDetector;

  @override
  void initState() {
    _bootCamera();
    super.initState();
  }

  void _bootCamera() async {
    var cameras = await availableCameras();
    if (cameras.length > 0) {
      var options = BarcodeDetectorOptions(barcodeFormats: BarcodeFormat.qrCode);
      barcodeDetector = FirebaseVision.instance.barcodeDetector(options);
      var pixelRatio = MediaQuery.of(context).devicePixelRatio;
      controller = CameraController(cameras[0], pixelRatio >= 2.5 ? ResolutionPreset.high : ResolutionPreset.medium);
      controller.initialize().then((_) {
        if (!mounted) {
          return;
        }

        controller.startImageStream((CameraImage availableImage) {
          checkForQr(availableImage);
        });

        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    if (controller != null) {
      controller.stopImageStream();
      controller.dispose();
    }
    super.dispose();
  }

  void checkForQr(CameraImage image) async {
    var metadata = FirebaseVisionImageMetadata(
        rawFormat: image.format.raw,
        size: Size(image.width.toDouble(),image.height.toDouble()),
        planeData: image.planes.map((currentPlane) => FirebaseVisionImagePlaneMetadata(
            bytesPerRow: currentPlane.bytesPerRow,
            height: currentPlane.height,
            width: currentPlane.width
        )).toList(),
        rotation: ImageRotation.rotation90
    );

    var firebaseVisionImage = FirebaseVisionImage.fromBytes(image.planes[0].bytes, metadata);
    barcodeDetector.detectInImage(firebaseVisionImage).then((barcodes) {
      if (barcodes.length > 0) {
        widget.onQRCodeCallback(barcodes.first.rawValue);
      }
    }).catchError((error) {
      widget.onQRError(error);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _cameraPreviewWidget();
  }

  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return new Container(color: Colors.black,);
    } else {
      final size = MediaQuery.of(context).size;
      final deviceRatio = size.width / size.height;
      return Transform.scale(
        scale: controller.value.aspectRatio / deviceRatio,
        child: Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),
      );
    }
  }
}