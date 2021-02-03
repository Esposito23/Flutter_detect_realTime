import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

List<CameraDescription> camereDisponibili;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  camereDisponibili = await availableCameras();
  runApp(MaterialApp(
    theme: ThemeData.dark(),
    home: CameraApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  CameraController controller;
  int selectedCameraIdx;
  String imagePath;
  bool isDetecting = false;
  String _model = "SSDMobileNet";
  int _imageWidth = 0;
  int _imageHeight = 0;
  List oggettiDetected;

  Future _loadModel() async {
    Tflite.close();
    await Tflite.loadModel(
      model: "assets/tflite/detect.tflite",
      labels: "assets/tflite/labelmap.txt",
    );
  }

  @override
  void initState() {
    super.initState();
    _loadModel();
    _initCameraController(camereDisponibili[0]);
  }

  Future _initCameraController(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }
    controller = CameraController(cameraDescription, ResolutionPreset.high);

    await controller.initialize();

    await getPredictions();
  }

  Future getPredictions() async {
    controller.startImageStream((CameraImage img) async {
      if (!isDetecting) {
        isDetecting = true;

        var recognitions = await Tflite.detectObjectOnFrame(
          bytesList: img.planes.map((plane) {
            return plane.bytes;
          }).toList(),
          model: _model,
          imageHeight: img.height,
          imageWidth: img.width,
          imageMean: 127.5,
          imageStd: 127.5,
          rotation: 90,
          numResultsPerClass: 1,
          threshold: 0.55,
          asynch: true,
        );
        recognitions.map((res) {
          _imageHeight = img.height;
          _imageWidth = img.width;
        });

        setState(() {
          oggettiDetected = recognitions;
        });
        isDetecting = false;
      }
    });
  }

  List<Widget> renderBoxes(Size screen) {
    if (oggettiDetected == null) return [];
    if (_imageWidth == null || _imageHeight == null) return [];

    double factorX = math.min(500, screen.width);
    double factorY = math.max(500, screen.width);

    Color red = Colors.red;
    return oggettiDetected.map((detected) {
      return Positioned(
        left: detected['rect']['x'] * factorX,
        top: detected['rect']['y'] * factorY,
        width: detected['rect']['w'] * factorX,
        height: detected['rect']['h'] * factorY,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: red, width: 2),
          ),
          child: Text(
            "${detected["detectedClass"]}",
          ),
        ),
      );
    }).toList();
  }

  Widget mostraCamera() {
    if (controller == null || !controller.value.isInitialized) {
      return (Text('Caricamento'));
    }

    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: CameraPreview(controller),
    );
  }

  /////////////////////////////////////////////////////////////
  ////////////////////////// build  //////////////////////////
  ///////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    List<Widget> _stackChildren = [];

    _stackChildren.add(
      Container(
        height: 500,
        width: size.width,
        child: mostraCamera(),
      ),
    );

    _stackChildren.addAll(renderBoxes(size));

    return Scaffold(
      appBar: AppBar(
        title: Text("Test Camera RealDetections"),
        centerTitle: true,
      ),
      body: Container(
        height: size.height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              height: 500,
              width: size.width,
              color: Colors.green,
              child: Stack(children: _stackChildren),
            ),
          ],
        ),
      ),
    );
  }
}
