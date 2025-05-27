import 'package:cpp_sample/native_add.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  Uint8List? _encodedImageBytes;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  // 画像を選択し、C++でエンコードして表示
  Future<void> _pickAndEncodeImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    // 画像の幅・高さを取得（ここでは仮に512x512とする。実際は画像から取得してください）
    // 例: https://pub.dev/packages/image などで画像サイズ取得可能
    // ここでは仮の値
    int width = 512;
    int height = 512;

    // 必要に応じて画像サイズを取得する処理を追加してください

    final encoded = await encodeImageWithCpp(bytes, height, width);
    setState(() {
      _encodedImageBytes = encoded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('You have pushed the button this many times:'),
              Text(
                '$_counter',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text('1 + 2 == ${nativeAdd(1, 99)}'),
              Text('testFunction(1, 2) == ${testFunction(1, 2)}'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _pickAndEncodeImage,
                child: const Text('画像を選択してC++でエンコード'),
              ),
              if (_encodedImageBytes != null) ...[
                const SizedBox(height: 16),
                const Text('C++でエンコードした画像:'),
                Image.memory(_encodedImageBytes!),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
