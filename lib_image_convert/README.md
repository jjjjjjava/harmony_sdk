# @prq/image-converter

HarmonyOS 图片格式转换工具库 —— 基于原生 Image API 实现，零依赖，轻量高效。

## 特性

-  **零依赖** - 使用 HarmonyOS 原生 API，无需额外库
-  **轻量级** - 不增加应用包体积
- **高性能** - 硬件加速，转换速度快（~0.3秒）
- **格式丰富** - 支持 JPEG、PNG、WEBP、GIF、HEIF
- **功能完整** - 格式转换、压缩、缩放、批量处理
- **简单易用** - 链式 API，几行代码搞定

## 安装

```bash
ohpm install @prq/image-converter
```

## 快速开始

### 基本使用

```typescript
import { ImageConverter, ImageFormat } from '@prq/image-converter';

// 转换图片格式
await ImageConverter.convert(
  '/path/to/input.jpg',
  '/path/to/output.webp',
  {
    format: ImageFormat.WEBP,
    quality: 90
  }
);
```

### 使用工厂类（更简单）

```typescript
import { ImageFactory } from '@prq/image-converter';

// JPEG → WEBP
await ImageFactory.toWebp('/path/to/input.jpg', '/path/to/output.webp');

// PNG → JPEG
await ImageFactory.toJpeg('/path/to/input.png', '/path/to/output.jpg', 90);

// 任意格式 → PNG
await ImageFactory.toPng('/path/to/input.jpg', '/path/to/output.png');
```

## 核心功能

### 1. 格式转换

支持所有主流图片格式互转：

```typescript
import { ImageConverter, ImageFormat } from '@prq/image-converter';

// JPEG → WEBP
await ImageConverter.convert(input, output, {
  format: ImageFormat.WEBP,
  quality: 90
});

// PNG → JPEG
await ImageConverter.convert(input, output, {
  format: ImageFormat.JPEG,
  quality: 85
});

// 任意格式 → HEIF（最新格式，体积最小）
await ImageConverter.convert(input, output, {
  format: ImageFormat.HEIF,
  quality: 90
});
```

### 2. 图片压缩

保持原格式，降低文件大小：

```typescript
// 压缩为原格式的 80% 质量
await ImageConverter.compress(
  '/path/to/input.jpg',
  '/path/to/output.jpg',
  80
);
```

### 3. 图片缩放

转换的同时调整尺寸：

```typescript
await ImageConverter.convert(input, output, {
  format: ImageFormat.JPEG,
  quality: 90,
  width: 800,   // 目标宽度
  height: 600   // 目标高度
});

// 或使用专用方法
await ImageConverter.resize(input, output, 800, 600);
```

### 4. 批量转换

一次转换多张图片：

```typescript
const inputs = [
  '/path/to/image1.jpg',
  '/path/to/image2.png',
  '/path/to/image3.bmp'
];

const outputs = await ImageConverter.convertBatch(
  inputs,
  '/path/to/output',
  {
    format: ImageFormat.WEBP,
    quality: 90
  }
);

console.log('转换完成:', outputs);
```

### 5. 获取图片信息

不解码，快速获取图片元数据：

```typescript
const info = await ImageConverter.getImageInfo('/path/to/image.jpg');

console.log('宽度:', info.size.width);
console.log('高度:', info.size.height);
console.log('格式:', info.mimeType);
```

## API 文档

### ImageConverter（核心类）

#### convert()

转换图片格式

```typescript
static async convert(
  inputPath: string,
  outputPath: string,
  options: ConvertOptions
): Promise<void>
```

**参数：**
- `inputPath`: 输入图片路径
- `outputPath`: 输出图片路径
- `options`: 转换选项
  - `format`: 目标格式（ImageFormat）
  - `quality?`: 质量 0-100，默认 90
  - `width?`: 目标宽度（可选）
  - `height?`: 目标高度（可选）

#### compress()

压缩图片（保持原格式）

```typescript
static async compress(
  inputPath: string,
  outputPath: string,
  quality: number
): Promise<void>
```

#### resize()

调整图片尺寸

```typescript
static async resize(
  inputPath: string,
  outputPath: string,
  width: number,
  height: number,
  format?: ImageFormat
): Promise<void>
```

#### convertBatch()

批量转换

```typescript
static async convertBatch(
  inputs: string[],
  outputDir: string,
  options: ConvertOptions
): Promise<string[]>
```

#### getImageInfo()

获取图片信息

```typescript
static async getImageInfo(path: string): Promise<ImageInfo>
```

### ImageFactory（工厂类）

快捷方法，无需指定格式：

```typescript
// 转换为 JPEG
static async toJpeg(input: string, output: string, quality?: number): Promise<void>

// 转换为 PNG
static async toPng(input: string, output: string): Promise<void>

// 转换为 WEBP
static async toWebp(input: string, output: string, quality?: number): Promise<void>

// 转换为 BMP
static async toBmp(input: string, output: string): Promise<void>

// 转换为 GIF
static async toGif(input: string, output: string): Promise<void>

// 转换为 HEIF
static async toHeif(input: string, output: string, quality?: number): Promise<void>
```

### ImageFormat（枚举）

支持的图片格式：

```typescript
enum ImageFormat {
  JPEG = 'image/jpeg',
  PNG = 'image/png',
  WEBP = 'image/webp',
  BMP = 'image/bmp',
  GIF = 'image/gif',
  HEIF = 'image/heif'
}
```

## 性能测试

测试环境：HarmonyOS 5.0, 1224x2776 JPEG (380KB)

| 操作 | 耗时 | 输出大小 | 说明 |
|------|------|---------|------|
| JPEG → WEBP | 0.33s | 245KB | 体积减少 35% |
| JPEG → PNG | 0.40s | 1.2MB | 无损格式 |
| PNG → JPEG | 0.35s | 380KB | 有损压缩 |
| 压缩 (80%) | 0.30s | 190KB | 体积减少 50% |
| 缩放 (50%) | 0.15s | 95KB | 尺寸减半 |

## 使用场景

### 1. 用户头像上传

```typescript
// 压缩并转换为 WEBP，减少上传流量
await ImageConverter.convert(originalPath, uploadPath, {
  format: ImageFormat.WEBP,
  quality: 85,
  width: 512,
  height: 512
});
```

### 2. 图片缓存优化

```typescript
// 下载的图片转换为 WEBP 缓存，节省存储空间
await ImageFactory.toWebp(downloadedPath, cachedPath, 90);
```

### 3. 相册导出

```typescript
// 批量转换相册图片
const photos = await getPhotoList();
await ImageConverter.convertBatch(photos, exportDir, {
  format: ImageFormat.JPEG,
  quality: 90
});
```

### 4. 缩略图生成

```typescript
// 生成缩略图
await ImageConverter.resize(
  originalPath,
  thumbnailPath,
  200,
  200,
  ImageFormat.JPEG
);
```

## 实现原理

### 核心思路

图片格式转换的本质：**解压 → 像素数据 → 重新压缩**

```
输入图片 → 解码为 PixelMap → 编码为目标格式 → 输出图片
```

### 为什么快？

1. **硬件加速** - 使用 GPU 解码和编码
2. **原生 API** - 直接调用系统编解码器
3. **零拷贝** - 内存中直接处理，无需临时文件

### 对比 FFmpeg

| 对比项 | 原生 API | FFmpeg |
|--------|---------|--------|
| 包体积 | 0 KB | 70 MB |
| 转换速度 | 0.3s | 0.5s+ |
| WEBP 支持 | 原生 | 需编译 |
| 并发支持 | 支持 | 串行 |
| 代码复杂度 | 简单 | 复杂 |

## 注意事项

1. **文件路径** - 使用应用沙箱路径，不能直接访问相册
2. **内存占用** - 大图片会占用较多内存（宽×高×4 字节）
3. **格式支持** - 所有格式都由系统支持，无需配置

## 常见问题

### Q: 支持哪些格式？
A: JPEG、PNG、WEBP、GIF、HEIF，系统原生支持。

### Q: 转换速度如何？
A: 1224x2776 图片约 0.3 秒，使用硬件加速。

### Q: 会增加包体积吗？
A: 不会，使用系统 API，零依赖。

### Q: 支持批量转换吗？
A: 支持，使用 `convertBatch()` 方法。

### Q: 可以调整图片尺寸吗？
A: 可以，在转换时指定 `width` 和 `height`。

## 更新日志

### v1.0.0 (2024-12-23)

- ✨ 首次发布
-  支持 6 种主流图片格式
- 支持格式转换、压缩、缩放
- 支持批量处理
- 完整的 TypeScript 类型定义

## 贡献

欢迎提交 Issue 和 Pull Request！

## License

MIT
