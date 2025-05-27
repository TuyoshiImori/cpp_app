import 'dart:ffi'; // For FFI
import 'dart:io'; // For Platform.isX
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// 返り値をクラスでまとめる
class EncodeResult {
  final Uint8List bytes;
  final int length;
  EncodeResult(this.bytes, this.length);
}

final DynamicLibrary nativeAddLib =
    Platform.isAndroid
        ? DynamicLibrary.open('libnative_add.so')
        : DynamicLibrary.process();

// DynamicLibraryオブジェクトから検索された関数をDartの関数型に変換
final int Function(int x, int y) nativeAdd =
    nativeAddLib
        .lookup<NativeFunction<Int32 Function(Int32, Int32)>>('native_add')
        .asFunction();

final int Function(int x, int y) testFunction =
    nativeAddLib
        .lookup<NativeFunction<Int32 Function(Int32, Int32)>>('testFunction')
        .asFunction();

// encodeIm関数のDart側定義
final int Function(
  int dataLen,
  Pointer<Uint8> bytes,
  Pointer<Pointer<Uint8>> encodedOutput,
)
encodeIm =
    nativeAddLib
        .lookup<
          NativeFunction<
            Int32 Function(Int32, Pointer<Uint8>, Pointer<Pointer<Uint8>>)
          >
        >('encodeIm')
        .asFunction();

// 画像データをC++に渡してJPEGエンコードし、結果をUint8Listで受け取る関数例
Future<EncodeResult> encodeImageWithCpp(Uint8List rawBytes) async {
  final Pointer<Uint8> bytesPtr = malloc.allocate<Uint8>(rawBytes.length);
  bytesPtr.asTypedList(rawBytes.length).setAll(0, rawBytes);

  final Pointer<Pointer<Uint8>> encodedOutputPtr = malloc
      .allocate<Pointer<Uint8>>(1);

  final int encodedLen = encodeIm(rawBytes.length, bytesPtr, encodedOutputPtr);

  final Pointer<Uint8> cppPointer = encodedOutputPtr.value;
  final Uint8List encodedBytes = Uint8List.fromList(
    cppPointer.asTypedList(encodedLen),
  );

  malloc.free(bytesPtr);
  malloc.free(encodedOutputPtr);
  malloc.free(cppPointer);

  return EncodeResult(encodedBytes, encodedLen);
}
