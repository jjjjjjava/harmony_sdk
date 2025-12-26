/**
 * 图片尺寸信息
 */
export interface ImageSize {
  width: number;
  height: number;
}
/**
 * 图片信息
 */
export interface ImageInfo {
  /** 图片尺寸 */
  size: ImageSize;
  
  /** MIME 类型 */
  mimeType: string;
  
  /** 是否为 HDR */
  isHdr?: boolean;
}
