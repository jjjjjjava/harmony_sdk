import { ImageFormat } from './ImageFormat';

/**
 * 图片转换选项
 */
export interface ConvertOptions {
  /** 目标格式 */
  format: ImageFormat;
  
  /** 质量 0-100，默认 90 */
  quality?: number;
  
  /** 目标宽度（可选，用于缩放） */
  width?: number;
  
  /** 目标高度（可选，用于缩放） */
  height?: number;
}
