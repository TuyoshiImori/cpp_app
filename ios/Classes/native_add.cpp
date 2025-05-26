// 🔽 dartから呼び出したいC++関数で、引数を足して返す単純な関数です。
// 先に言っておくと、iosフォルダの中のファイルをandroidでも参照する構成にしていきます。
#include <stdint.h>
#include <opencv2/opencv.hpp>

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int32_t
native_add(int32_t x, int32_t y)
{
    return x + y;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used)) int testFunction(int rows, int cols)
{
    cv::Mat mat(rows, cols, CV_8UC1);
    // 何もせずに0を返す
    return 0;
}