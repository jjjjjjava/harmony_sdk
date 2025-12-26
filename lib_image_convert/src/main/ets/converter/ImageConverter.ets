/**
 * 图片格式转换核心类
 * 
 * 基于 HarmonyOS 原生 Image API 实现
 * 支持硬件加速，性能优秀
 */

import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { ConvertOptions } from '../types/ConvertOptions';
import { ImageInfo } from '../types/ImageInfo';
import { ImageFormat } from '../types/ImageFormat';
import { ILog } from '../utils/ILog';
import { ImageUtils } from '../utils/ImageUtils';

export class ImageConverter {
  /**
   * 转换图片格式
   * 
   * @param inputPath 输入图片路径
   * @param outputPath 输出图片路径
   * @param options 转换选项
   */
  static async convert(
    inputPath: string,
    outputPath: string,
    options: ConvertOptions
  ): Promise<void> {
    const startTime = Date.now();
    
    try {
      ILog.info(`[ImageConverter] 开始转换: ${inputPath} → ${outputPath}`);
      ILog.info(`[ImageConverter] 目标格式: ${options.format}, 质量: ${options.quality || 90}`);
      
      // 1. 创建图片源
      const imageSource = image.createImageSource(inputPath);
      
      // 2. 获取图片信息
      const imageInfo = await imageSource.getImageInfo();
      ILog.info(`[ImageConverter] 原图尺寸: ${imageInfo.size.width}x${imageInfo.size.height}`);
      
      // 3. 解码为 PixelMap
      const decodingOptions: image.DecodingOptions = {
        editable: true,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      
      // 如果指定了尺寸，进行缩放
      if (options.width || options.height) {
        decodingOptions.desiredSize = {
          width: options.width || imageInfo.size.width,
          height: options.height || imageInfo.size.height
        };
        ILog.info(`[ImageConverter] 缩放至: ${decodingOptions.desiredSize.width}x${decodingOptions.desiredSize.height}`);
      }
      
      const pixelMap = await imageSource.createPixelMap(decodingOptions);
      ILog.info(`[ImageConverter] PixelMap 创建成功`);
      
      // 4. 创建图片打包器
      const packer = image.createImagePacker();
      
      // 5. 配置打包选项
      const packOpts: image.PackingOption = {
        format: options.format,
        quality: options.quality || 90
      };
      
      // 6. 打包为目标格式
      const data = await packer.packing(pixelMap, packOpts);
      ILog.info(`[ImageConverter] 编码完成, 数据大小: ${(data.byteLength / 1024).toFixed(2)} KB`);
      
      // 7. 写入文件
      const file = fileIo.openSync(outputPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file);
      
      // 8. 获取输出文件大小
      const stat = fileIo.statSync(outputPath);
      const outputSizeKB = (stat.size / 1024).toFixed(2);
      
      // 9. 释放资源
      pixelMap.release();
      await imageSource.release();
      
      const duration = ((Date.now() - startTime) / 1000).toFixed(2);
      ILog.info(`[ImageConverter] 转换成功: ${outputPath}, 大小: ${outputSizeKB} KB, 耗时: ${duration}s`);
      
    } catch (error) {
      ILog.error(`[ImageConverter] 转换失败: ${error}`);
      throw error as Error;
    }
  }
  
  /**
   * 批量转换图片
   * 
   * @param inputs 输入图片路径数组
   * @param outputDir 输出目录
   * @param options 转换选项
   * @returns 输出文件路径数组
   */
  static async convertBatch(
    inputs: string[],
    outputDir: string,
    options: ConvertOptions
  ): Promise<string[]> {
    ILog.info(`[ImageConverter] 批量转换开始, 共 ${inputs.length} 张图片`);
    const results: string[] = [];
    
    for (let i = 0; i < inputs.length; i++) {
      const input = inputs[i];
      const fileName = input.substring(input.lastIndexOf('/') + 1);
      const baseName = fileName.substring(0, fileName.lastIndexOf('.'));
      const ext = ImageUtils.getExtension(options.format);
      const output = `${outputDir}/${baseName}.${ext}`;
      
      ILog.info(`[ImageConverter] 处理 ${i + 1}/${inputs.length}: ${fileName}`);
      
      try {
        await ImageConverter.convert(input, output, options);
        results.push(output);
      } catch (error) {
        ILog.error(`[ImageConverter] 转换失败: ${fileName}, 错误: ${error}`);
        // 继续处理下一张
      }
    }
    
    ILog.info(`[ImageConverter] 批量转换完成, 成功: ${results.length}/${inputs.length}`);
    return results;
  }
  
  /**
   * 获取图片信息（不解码）
   * 
   * @param path 图片路径
   * @returns 图片信息
   */
  static async getImageInfo(path: string): Promise<ImageInfo> {
    try {
      const imageSource = image.createImageSource(path);
      const info = await imageSource.getImageInfo();
      await imageSource.release();
      
      return {
        size: {
          width: info.size.width,
          height: info.size.height
        },
        mimeType: info.mimeType,
        isHdr: info.isHdr
      };
    } catch (error) {
      ILog.error(`[ImageConverter] 获取图片信息失败: ${error}`);
      throw error as Error;
    }
  }
  
  /**
   * 压缩图片（保持原格式）
   * 
   * @param inputPath 输入图片路径
   * @param outputPath 输出图片路径
   * @param quality 质量 0-100
   */
  static async compress(
    inputPath: string,
    outputPath: string,
    quality: number = 80
  ): Promise<void> {
    try {
      // 获取原图格式
      const info = await ImageConverter.getImageInfo(inputPath);
      
      // 根据原格式压缩
      let format = ImageFormat.JPEG;
      if (info.mimeType === 'image/png') {
        format = ImageFormat.PNG;
      } else if (info.mimeType === 'image/webp') {
        format = ImageFormat.WEBP;
      } else if (info.mimeType === 'image/bmp') {
        format = ImageFormat.BMP;
      } else if (info.mimeType === 'image/gif') {
        format = ImageFormat.GIF;
      } else if (info.mimeType === 'image/heif' || info.mimeType === 'image/heic') {
        format = ImageFormat.HEIF;
      }
      
      ILog.info(`[ImageConverter] 压缩图片, 格式: ${format}, 质量: ${quality}`);
      
      await ImageConverter.convert(inputPath, outputPath, { format, quality });
    } catch (error) {
      ILog.error(`[ImageConverter] 压缩失败: ${error}`);
      throw error as Error;
    }
  }
  
  /**
   * 调整图片尺寸
   * 
   * @param inputPath 输入图片路径
   * @param outputPath 输出图片路径
   * @param width 目标宽度
   * @param height 目标高度
   * @param format 输出格式，默认 JPEG
   */
  static async resize(
    inputPath: string,
    outputPath: string,
    width: number,
    height: number,
    format: ImageFormat = ImageFormat.JPEG
  ): Promise<void> {
    ILog.info(`[ImageConverter] 调整尺寸: ${width}x${height}`);
    
    await ImageConverter.convert(inputPath, outputPath, {
      format,
      width,
      height,
      quality: 90
    });
  }
}
