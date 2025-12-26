/**
 * 图片格式枚举
 * 
 * 支持的所有图片格式
 */
export enum ImageFormat {
  /** JPEG 格式 - 有损压缩，适合照片 */
  JPEG = 'image/jpeg',
  
  /** PNG 格式 - 无损压缩，支持透明 */
  PNG = 'image/png',
  
  /** WEBP 格式 - 现代格式，体积小 */
  WEBP = 'image/webp',
  
  /** BMP 格式 - 位图格式，体积大 */
  BMP = 'image/bmp',
  
  /** GIF 格式 - 支持动画 */
  GIF = 'image/gif',
  
  /** HEIF 格式 - 最新格式，体积最小 */
  HEIF = 'image/heif'
}
