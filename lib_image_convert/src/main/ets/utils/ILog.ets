/**
 * 日志工具类
 */

export class ILog {
  private static enabled: boolean = true;
  
  /**
   * 启用/禁用日志
   * 
   * @param enable 是否启用
   */
  static setEnabled(enable: boolean): void {
    ILog.enabled = enable;
  }
  
  /**
   * 信息日志
   * 
   * @param message 消息
   */
  static info(message: string): void {
    if (ILog.enabled) {
      console.info(message);
    }
  }
  
  /**
   * 警告日志
   * 
   * @param message 消息
   */
  static warn(message: string): void {
    if (ILog.enabled) {
      console.warn(message);
    }
  }
  
  /**
   * 错误日志
   * 
   * @param message 消息
   */
  static error(message: string): void {
    if (ILog.enabled) {
      console.error(message);
    }
  }
  
  /**
   * 调试日志
   * 
   * @param message 消息
   */
  static debug(message: string): void {
    if (ILog.enabled) {
      console.debug(message);
    }
  }
}
