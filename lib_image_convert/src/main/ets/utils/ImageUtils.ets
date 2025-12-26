/**
 * 图片工具类
 */

import { ImageFormat } from '../types/ImageFormat';

export interface ImageSize {
  width: number;
  height: number;
}

export class ImageUtils {
  /**
   * 根据格式获取文件扩展名
   * 
   * @param format 图片格式
   * @returns 文件扩展名
   */
  static getExtension(format: ImageFormat): string {
    switch (format) {
      case ImageFormat.JPEG:
        return 'jpg';
      case ImageFormat.PNG:
        return 'png';
      case ImageFormat.WEBP:
        return 'webp';
      case ImageFormat.BMP:
        return 'bmp';
      case ImageFormat.GIF:
        return 'gif';
      case ImageFormat.HEIF:
        return 'heic';
      default:
        return 'jpg';
    }
  }
  
  /**
   * 根据文件扩展名获取格式
   * 
   * @param extension 文件扩展名
   * @returns 图片格式
   */
  static getFormatFromExtension(extension: string): ImageFormat {
    const ext = extension.toLowerCase().replace('.', '');
    
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return ImageFormat.JPEG;
      case 'png':
        return ImageFormat.PNG;
      case 'webp':
        return ImageFormat.WEBP;
      case 'bmp':
        return ImageFormat.BMP;
      case 'gif':
        return ImageFormat.GIF;
      case 'heic':
      case 'heif':
        return ImageFormat.HEIF;
      default:
        return ImageFormat.JPEG;
    }
  }
  
  /**
   * 格式化文件大小
   * 
   * @param bytes 字节数
   * @returns 格式化后的字符串
   */
  static formatFileSize(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    } else if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(2)} KB`;
    } else {
      return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
    }
  }
  
  /**
   * 计算缩放后的尺寸（保持宽高比）
   * 
   * @param originalWidth 原始宽度
   * @param originalHeight 原始高度
   * @param maxWidth 最大宽度
   * @param maxHeight 最大高度
   * @returns 缩放后的尺寸
   */
  static calculateScaledSize(
    originalWidth: number,
    originalHeight: number,
    maxWidth: number,
    maxHeight: number
  ): ImageSize {
    const widthRatio = maxWidth / originalWidth;
    const heightRatio = maxHeight / originalHeight;
    const ratio = Math.min(widthRatio, heightRatio);
    
    return {
      width: Math.round(originalWidth * ratio),
      height: Math.round(originalHeight * ratio)
    };
  }
}
