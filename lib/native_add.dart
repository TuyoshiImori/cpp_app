import 'dart:ffi'; // For FFI
import 'dart:io'; // For Platform.isX
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

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
  int height,
  int width,
  Pointer<Uint8> bytes,
  Pointer<Pointer<Uint8>> encodedOutput,
)
encodeIm =
    nativeAddLib
        .lookup<
          NativeFunction<
            Int32 Function(
              Int32,
              Int32,
              Pointer<Uint8>,
              Pointer<Pointer<Uint8>>,
            )
          >
        >('encodeIm')
        .asFunction();

// 画像データをC++に渡してJPEGエンコードし、結果をUint8Listで受け取る関数例
Future<Uint8List> encodeImageWithCpp(
  Uint8List rawBytes,
  int height,
  int width,
) async {
  // 入力画像データ用のネイティブメモリ確保
  final Pointer<Uint8> bytesPtr = malloc.allocate<Uint8>(rawBytes.length);
  bytesPtr.asTypedList(rawBytes.length).setAll(0, rawBytes);

  // エンコード後のデータへのポインタ（8バイト分確保）
  final Pointer<Pointer<Uint8>> encodedOutputPtr = malloc
      .allocate<Pointer<Uint8>>(1);

  // C++関数呼び出し
  final int encodedLen = encodeIm(height, width, bytesPtr, encodedOutputPtr);

  // C++側でmallocされたメモリのポインタを取得
  final Pointer<Uint8> cppPointer = encodedOutputPtr.value;

  // DartのUint8Listとして受け取る
  final Uint8List encodedBytes = cppPointer.asTypedList(encodedLen);

  // メモリ解放
  malloc.free(bytesPtr);
  malloc.free(encodedOutputPtr);
  malloc.free(cppPointer);

  return encodedBytes;
}
