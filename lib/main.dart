import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras[1];
  runApp(MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen),
      useMaterial3: true,
    ),
    home: CameraScreen(camera: firstCamera),
  ));
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.camera});
  final CameraDescription camera;

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();

    _controller = CameraController(
      widget.camera,
      ResolutionPreset.max,
    );

    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            Theme.of(context).colorScheme.inversePrimary.withOpacity(0.5),
        title: const Text('UGRP'),
        centerTitle: true,
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await _initializeControllerFuture;
            final image = await _controller.takePicture();
            final String imgPath = image.path;
            // create image id imgid with random uid
            if (!mounted) return;

            // send image to server to wait for getting result
            print('[[[IMGPATH]]]: ' + imgPath);
            // List<int> imageBytes = image.readAsBytesSync();
            File imageFile = new File(imgPath);
            List<int> imageBytes = imageFile.readAsBytesSync();
            String imagestring = base64Encode(imageBytes);

            final prediction = await http.post(
              Uri.parse('http://10.0.2.2:8080/predict'),
              body: jsonEncode({'file': imagestring}),
              // body: imagestring,
            );

            if (prediction.statusCode == 200) {
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => ResultScreen(
                        imgPath: imgPath,
                        result: prediction.body,
                      )));
            } else {
              throw ('Failed to get prediction', prediction.statusCode);
            }
          } catch (e) {
            print(e);
          }
        },
        tooltip: 'Take a photo and detect the object',
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

class ResultScreen extends StatefulWidget {
  final String imgPath;
  final String result;
  ResultScreen({super.key, required this.imgPath, required this.result});

  @override
  ResultScreenState createState() => ResultScreenState();
}

class PredictResult {
  final Map<int, String> result;
  const PredictResult({required this.result});
  factory PredictResult.fromJson(Map<String, dynamic> json) {
    return PredictResult(
      result: {
        json['result'][0]['id']: json['result'][0]['name'],
        json['result'][1]['id']: json['result'][1]['name'],
        json['result'][2]['id']: json['result'][2]['name'],
      },
    );
  }
}

class ResultScreenState extends State<ResultScreen> {
  // wait for server response, then show result
  // final String imgPath;
  // PredictResult result = PredictResult.fromJson(widget.result);
  @override
  Widget build(BuildContext context) {
    Map resultmap = json.decode(widget.result);

    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            Theme.of(context).colorScheme.inversePrimary.withOpacity(0.5),
        title: const Text('Results'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flex(
                direction: Axis.vertical,
                children: [
                  Container(
                    height: MediaQuery.of(context).size.height / 2,
                    margin: const EdgeInsets.all(10),
                    child: Image.file(
                      File(widget.imgPath),
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ListTile(
                      title: Text(resultmap["1"][1]),
                      trailing: Text(resultmap['1'][0]),
                    ),
                    ListTile(
                      title: Text(resultmap["2"][1]),
                      trailing: Text(resultmap['2'][0]),
                    ),
                    ListTile(
                      title: Text(resultmap["3"][1]),
                      trailing: Text(resultmap['3'][0]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}