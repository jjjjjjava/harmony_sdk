/**
 * 图片转换工厂类
 * 
 * 提供快捷方法，无需指定格式参数
 */

import { ImageConverter } from './ImageConverter';
import { ImageFormat } from '../types/ImageFormat';

export class ImageFactory {
  /**
   * 转换为 JPEG 格式
   * 
   * @param inputPath 输入图片路径
   * @param outputPath 输出图片路径
   * @param quality 质量 0-100，默认 90
   */
  static async toJpeg(
    inputPath: string,
    outputPath: string,
    quality: number = 90
  ): Promise<void> {
    await ImageConverter.convert(inputPath, outputPath, {
      format: ImageFormat.JPEG,
      quality
    });
  }
  
  /**
   * 转换为 PNG 格式
   * 
   * @param inputPath 输入图片路径
   * @param outputPath 输出图片路径
   */
  static async toPng(
    inputPath: string,
    outputPath: string
  ): Promise<void> {
    await ImageConverter.convert(inputPath, outputPath, {
      format: ImageFormat.PNG,
      quality: 100  // PNG 无损
    });
  }
  
  /**
   * 转换为 WEBP 格式
   * 
   * @param inputPath 输入图片路径
   * @param outputPath 输出图片路径
   * @param quality 质量 0-100，默认 90
   */
  static async toWebp(
    inputPath: string,
    outputPath: string,
    quality: number = 90
  ): Promise<void> {
    await ImageConverter.convert(inputPath, outputPath, {
      format: ImageFormat.WEBP,
      quality
    });
  }
  
  /**
   * 转换为 BMP 格式
   * 
   * @param inputPath 输入图片路径
   * @param outputPath 输出图片路径
   */
  static async toBmp(
    inputPath: string,
    outputPath: string
  ): Promise<void> {
    await ImageConverter.convert(inputPath, outputPath, {
      format: ImageFormat.BMP,
      quality: 100
    });
  }
  
  /**
   * 转换为 GIF 格式
   * 
   * @param inputPath 输入图片路径
   * @param outputPath 输出图片路径
   */
  static async toGif(
    inputPath: string,
    outputPath: string
  ): Promise<void> {
    await ImageConverter.convert(inputPath, outputPath, {
      format: ImageFormat.GIF,
      quality: 100
    });
  }
  
  /**
   * 转换为 HEIF 格式
   * 
   * @param inputPath 输入图片路径
   * @param outputPath 输出图片路径
   * @param quality 质量 0-100，默认 90
   */
  static async toHeif(
    inputPath: string,
    outputPath: string,
    quality: number = 90
  ): Promise<void> {
    await ImageConverter.convert(inputPath, outputPath, {
      format: ImageFormat.HEIF,
      quality
    });
  }
}
