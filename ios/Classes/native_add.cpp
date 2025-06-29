// 🔽 dartから呼び出したいC++関数で、引数を足して返す単純な関数です。
// 先に言っておくと、iosフォルダの中のファイルをandroidでも参照する構成にしていきます。
#include <stdint.h>
#include <opencv2/opencv.hpp>
#include <vector>

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int32_t
native_add(int32_t x, int32_t y)
{
    return x + y;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
// テスト用の関数
int
testFunction(int rows, int cols)
{
    cv::Mat mat(rows, cols, CV_8UC1);
    // 何もせずに0を返す
    return 0;
}

// Dartから呼び出すためのエクスポート設定
extern "C" __attribute__((visibility("default"))) __attribute__((used))
// 画像エンコード関数
// dataLen: 入力画像データのバイト数, rawBytes: 入力画像データ, encodedOutput: エンコード後のデータへのポインタ
int
encodeIm(int dataLen, unsigned char *rawBytes, unsigned char **encodedOutput)
{
    // 入力データ（JPEG/PNG/HEICなど）をOpenCVでデコード
    std::vector<uchar> inputVec(rawBytes, rawBytes + dataLen);
    cv::Mat img = cv::imdecode(inputVec, cv::IMREAD_COLOR);

    if (img.empty())
    {
        // デコード失敗時は0を返す
        *encodedOutput = nullptr;
        return 0;
    }

    // エンコード結果を格納するバッファ
    std::vector<uchar> buf;
    // JPEG形式でエンコード
    cv::imencode(".jpg", img, buf);

    // エンコード後のバイト列をmallocで確保したメモリにコピー
    *encodedOutput = (unsigned char *)malloc(buf.size());
    for (size_t i = 0; i < buf.size(); i++)
    {
        (*encodedOutput)[i] = buf[i];
    }
    // エンコード後のバイト数を返す
    return (int)buf.size();
}