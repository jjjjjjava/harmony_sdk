/**
 * 转换回调接口
 */
export interface ConvertCallback {
  /** 转换开始 */
  onStart?: () => void;
  
  /** 转换进度 (0-100) */
  onProgress?: (progress: number) => void;
  
  /** 转换成功 */
  onSuccess?: (outputPath: string) => void;
  
  /** 转换失败 */
  onFailure?: (error: Error) => void;
}
