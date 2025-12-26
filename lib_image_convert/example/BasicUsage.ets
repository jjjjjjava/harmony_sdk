/**
 * 基本使用示例
 */

import { ImageConverter, ImageFactory, ImageFormat } from '@prq/image-converter';

export class BasicUsageExample {
  /**
   * 示例 1: 基本格式转换
   */
  static async example1() {
    // JPEG → WEBP
    await ImageConverter.convert(
      '/path/to/input.jpg',
      '/path/to/output.webp',
      {
        format: ImageFormat.WEBP,
        quality: 90
      }
    );
  }
  
  /**
   * 示例 2: 使用工厂类（更简单）
   */
  static async example2() {
    // JPEG → WEBP
    await ImageFactory.toWebp('/path/to/input.jpg', '/path/to/output.webp');
    
    // PNG → JPEG
    await ImageFactory.toJpeg('/path/to/input.png', '/path/to/output.jpg', 85);
    
    // 任意格式 → PNG
    await ImageFactory.toPng('/path/to/input.jpg', '/path/to/output.png');
  }
  
  /**
   * 示例 3: 图片压缩
   */
  static async example3() {
    // 压缩为原格式的 80% 质量
    await ImageConverter.compress(
      '/path/to/input.jpg',
      '/path/to/output.jpg',
      80
    );
  }
  
  /**
   * 示例 4: 图片缩放
   */
  static async example4() {
    // 转换并缩放
    await ImageConverter.convert(
      '/path/to/input.jpg',
      '/path/to/output.jpg',
      {
        format: ImageFormat.JPEG,
        quality: 90,
        width: 800,
        height: 600
      }
    );
    
    // 或使用专用方法
    await ImageConverter.resize(
      '/path/to/input.jpg',
      '/path/to/output.jpg',
      800,
      600
    );
  }
  
  /**
   * 示例 5: 批量转换
   */
  static async example5() {
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
  }
  
  /**
   * 示例 6: 获取图片信息
   */
  static async example6() {
    const info = await ImageConverter.getImageInfo('/path/to/image.jpg');
    
    console.log('宽度:', info.size.width);
    console.log('高度:', info.size.height);
    console.log('格式:', info.mimeType);
  }
  
  /**
   * 示例 7: 完整的图片处理流程
   */
  static async example7() {
    try {
      // 1. 获取图片信息
      const info = await ImageConverter.getImageInfo('/path/to/input.jpg');
      console.log(`原图尺寸: ${info.size.width}x${info.size.height}`);
      
      // 2. 转换为 WEBP 并压缩
      await ImageConverter.convert(
        '/path/to/input.jpg',
        '/path/to/output.webp',
        {
          format: ImageFormat.WEBP,
          quality: 85,
          width: 1024,  // 限制最大宽度
          height: 1024  // 限制最大高度
        }
      );
      
      // 3. 验证输出
      const outputInfo = await ImageConverter.getImageInfo('/path/to/output.webp');
      console.log(`输出尺寸: ${outputInfo.size.width}x${outputInfo.size.height}`);
      
      console.log('转换成功！');
    } catch (error) {
      console.error('转换失败:', error);
    }
  }
}
