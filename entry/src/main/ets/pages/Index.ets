/**
 * FFmpeg 功能测试页面
 * 测试视频下载和转换功能
 *
 * 注意：FFmpeg 内部使用全局变量，不支持多线程并发执行
 * 多个任务会串行执行（队列模式）
 */

import { buffer } from '@kit.ArkTS';
import { FFmpegManager, FFmpegFactory, TaskCallback, FLog } from 'lib_ffmpeg_utils';
import { fileIo } from '@kit.CoreFileKit';

// 转换格式类型
type ConvertFormat = 'mp4' | 'flv' | 'avi' | 'mkv' | 'ts' | 'mp3' | 'aac';

@Entry
@Component
struct Index {
  // 测试视频 URL (base64 编码)
  static TEST_VIDEO_URL = buffer.from(
    'aHR0cHM6Ly9zbnMtdmlkZW8tYWwueGhzY2RuLmNvbS9zdHJlYW0vMTEwLzQwNS8wMWU1ODNjYjZlMGZlZDVhMDEwMzcwMDM4YzhhZDk2MmZiXzQwNS5tcDQ=',
    'base64'
  ).toString('binary');

  @State convertProgress: number = 0;
  @State statusText: string = '准备就绪';
  @State isConverting: boolean = false;
  @State logs: string[] = [];

  // 单任务耗时
  @State singleTaskTime: string = '--';
  // 格式转换耗时
  @State formatConvertTime: string = '--';
  // 当前选择的格式
  @State selectedFormat: ConvertFormat = 'flv';

  private outputFilePath: string = '';
  private taskId: string = '';

  aboutToAppear() {
    this.addLog('FFmpeg 测试页面初始化');
    this.addLog('⚠️ FFmpeg 不支持多线程并发，任务串行执行');
    this.addLog('支持格式: MP4, FLV, AVI, MKV, TS, MP3, AAC');
    this.outputFilePath = getContext().filesDir + '/test_output.mp4';
  }

  addLog(message: string) {
    const timestamp = new Date().toLocaleTimeString();
    const logMessage = `[${timestamp}] ${message}`;
    this.logs.push(logMessage);
    console.log(logMessage);
    FLog.info('FFmpegTest', message);
    if (this.logs.length > 50) {
      this.logs.shift();
    }
  }

  /**
   * 单任务转换测试
   */
  async convertVideoFromUrl() {
    if (this.isConverting) {
      this.addLog('⚠️ 正在转换中，请稍候...');
      return;
    }

    this.isConverting = true;
    this.convertProgress = 0;
    this.singleTaskTime = '计时中...';
    this.statusText = '开始从URL转换视频...';
    this.addLog('🚀 开始 FFmpeg 单任务转换');

    const startTime = Date.now();
    this.executeFFmpegConversion(startTime);
  }

  /**
   * 格式转换测试
   */
  async convertToFormat(format: ConvertFormat) {
    if (this.isConverting) {
      this.addLog('⚠️ 正在转换中，请稍候...');
      return;
    }

    this.isConverting = true;
    this.convertProgress = 0;
    this.formatConvertTime = '计时中...';
    this.selectedFormat = format;

    const outputPath = getContext().filesDir + `/test_output.${format}`;
    this.statusText = `转换为 ${format.toUpperCase()}...`;
    this.addLog(`🚀 开始转换: MP4 → ${format.toUpperCase()}`);
    this.addLog(`输出: ${outputPath}`);

    const startTime = Date.now();

    // 根据格式选择不同的转换命令
    let commands: string[];
    switch (format) {
      case 'flv':
        commands = FFmpegFactory.buildMp42Flv(Index.TEST_VIDEO_URL, outputPath);
        break;
      case 'avi':
        commands = FFmpegFactory.buildMp42Avi(Index.TEST_VIDEO_URL, outputPath);
        break;
      case 'mkv':
        commands = FFmpegFactory.buildMp42Mkv(Index.TEST_VIDEO_URL, outputPath);
        break;
      case 'ts':
        commands = FFmpegFactory.buildMp42Ts(Index.TEST_VIDEO_URL, outputPath);
        break;
      case 'mp3':
        commands = FFmpegFactory.buildExtractMp3(Index.TEST_VIDEO_URL, outputPath);
        break;
      case 'aac':
        commands = FFmpegFactory.buildExtractAac(Index.TEST_VIDEO_URL, outputPath);
        break;
      default:
        commands = FFmpegFactory.buildMp42Mp4(Index.TEST_VIDEO_URL, outputPath);
    }

    this.addLog(`命令: ${commands.join(' ')}`);

    try {
      this.taskId = FFmpegManager.getInstance().execute(
        commands,
        120000,
        Object({
          onStart: () => {
            this.addLog(`🎬 转换任务已启动`);
          },
          onProgress: (progress: number) => {
            this.convertProgress = progress * 100;
            this.statusText = `转换 ${format.toUpperCase()}: ${this.convertProgress.toFixed(1)}%`;
          },
          onSuccess: () => {
            const duration = ((Date.now() - startTime) / 1000).toFixed(2);
            this.formatConvertTime = `${duration}s`;
            this.statusText = `✅ 转换完成: ${format.toUpperCase()}`;
            this.addLog(`✅ 转换成功！`);
            this.addLog(`📊 耗时: ${duration}s`);
            this.checkOutputFileByPath(outputPath);
            this.isConverting = false;
          },
          onFailure: () => {
            this.formatConvertTime = '失败';
            this.statusText = `❌ 转换失败: ${format.toUpperCase()}`;
            this.addLog(`❌ 转换失败`);
            this.isConverting = false;
          },
          onTimeout: () => {
            this.formatConvertTime = '超时';
            this.statusText = '⏱️ 转换超时';
            this.addLog('⏱️ 任务超时');
            this.isConverting = false;
          },
          onCancelled: () => {
            this.formatConvertTime = '已取消';
            this.statusText = '🚫 已取消';
            this.addLog('🚫 任务已取消');
            this.isConverting = false;
          }
        }) as TaskCallback
      );

      this.addLog(`任务ID: ${this.taskId}`);
    } catch (error) {
      this.statusText = '❌ 执行错误';
      this.addLog(`❌ 执行错误: ${error}`);
      this.isConverting = false;
    }
  }

  async checkOutputFileByPath(path: string) {
    try {
      const stat = fileIo.statSync(path);
      this.addLog(`✅ 输出文件大小: ${(stat.size / 1024).toFixed(2)} KB`);
    } catch (error) {
      this.addLog(`⚠️ 无法读取输出文件: ${error}`);
    }
  }

  private executeFFmpegConversion(startTime: number) {
    try {
      this.taskId = FFmpegManager.getInstance().execute(
        FFmpegFactory.buildMp42Mp4(Index.TEST_VIDEO_URL, this.outputFilePath),
        120000,
        Object({
          onStart: () => {
            this.addLog('🎬 FFmpeg 任务已启动');
          },
          onProgress: (progress: number) => {
            this.convertProgress = progress * 100;
            this.statusText = `转换中: ${this.convertProgress.toFixed(1)}%`;
          },
          onSuccess: () => {
            const duration = ((Date.now() - startTime) / 1000).toFixed(2);
            this.singleTaskTime = `${duration}s`;
            this.statusText = '✅ 转换完成';
            this.addLog('✅ 视频转换成功！');
            this.addLog(`📊 单任务耗时: ${duration}s`);
            this.checkOutputFile();
            this.isConverting = false;
          },
          onFailure: () => {
            this.singleTaskTime = '失败';
            this.statusText = '❌ 转换失败';
            this.addLog('❌ 视频转换失败');
            this.isConverting = false;
          },
          onTimeout: () => {
            this.singleTaskTime = '超时';
            this.statusText = '⏱️ 转换超时';
            this.addLog('⏱️ 任务超时');
            this.isConverting = false;
          },
          onCancelled: () => {
            this.singleTaskTime = '已取消';
            this.statusText = '🚫 已取消';
            this.addLog('🚫 任务已取消');
            this.isConverting = false;
          }
        }) as TaskCallback
      );

      this.addLog(`任务ID: ${this.taskId}`);
    } catch (error) {
      this.statusText = '❌ 执行错误';
      this.addLog(`❌ 执行错误: ${error}`);
      this.isConverting = false;
    }
  }

  async checkOutputFile() {
    try {
      const stat = fileIo.statSync(this.outputFilePath);
      this.addLog(`✅ 输出文件大小: ${stat.size} 字节`);
    } catch (error) {
      this.addLog(`⚠️ 无法读取输出文件: ${error}`);
    }
  }

  cancelConvert() {
    if (this.taskId) {
      const success = FFmpegManager.getInstance().cancel(this.taskId);
      this.addLog(success ? '🚫 已取消转换任务' : '⚠️ 取消失败');
    }
  }

  clearLogs() {
    this.logs = [];
    this.addLog('日志已清空');
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('FFmpeg 功能测试')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')

      Scroll() {
        Column() {
          // 状态显示
          Column() {
            Text(this.statusText)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 12 })

            // 耗时对比区域
            Row() {
              Column() {
                Text('MP4复制耗时')
                  .fontSize(12)
                  .fontColor('#999999')
                Text(this.singleTaskTime)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FF9900')
              }
              .layoutWeight(1)

              Divider()
                .vertical(true)
                .height(40)
                .color('#E5E5E5')

              Column() {
                Text(`转${this.selectedFormat.toUpperCase()}耗时`)
                  .fontSize(12)
                  .fontColor('#999999')
                Text(this.formatConvertTime)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#007DFF')
              }
              .layoutWeight(1)
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
            .margin({ bottom: 12 })
            .backgroundColor('#F5F5F5')
            .borderRadius(8)

            // 转换进度
            Row() {
              Text('进度:')
                .fontSize(14)
                .width(50)
              Progress({ value: this.convertProgress, total: 100, type: ProgressType.Linear })
                .width('60%')
              Text(`${this.convertProgress.toFixed(1)}%`)
                .fontSize(12)
                .margin({ left: 8 })
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .margin({ top: 12, left: 16, right: 16 })

          // 操作按钮
          Column() {
            Text('MP4 直接复制')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .margin({ bottom: 8 })

            Button('MP4 复制 ⚡️')
              .width('100%')
              .height(44)
              .fontSize(16)
              .backgroundColor('#FF9900')
              .enabled(!this.isConverting)
              .onClick(() => {
                this.convertVideoFromUrl();
              })

            Divider()
              .margin({ top: 16, bottom: 16 })
              .color('#E5E5E5')

            Text('格式转换测试')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .margin({ bottom: 8 })

            // 视频格式按钮
            Row() {
              Button('FLV')
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .backgroundColor(this.selectedFormat === 'flv' ? '#007DFF' : '#999999')
                .enabled(!this.isConverting)
                .onClick(() => {
                  this.convertToFormat('flv');
                })

              Button('AVI')
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .margin({ left: 8 })
                .backgroundColor(this.selectedFormat === 'avi' ? '#007DFF' : '#999999')
                .enabled(!this.isConverting)
                .onClick(() => {
                  this.convertToFormat('avi');
                })

              Button('MKV')
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .margin({ left: 8 })
                .backgroundColor(this.selectedFormat === 'mkv' ? '#007DFF' : '#999999')
                .enabled(!this.isConverting)
                .onClick(() => {
                  this.convertToFormat('mkv');
                })

              Button('TS')
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .margin({ left: 8 })
                .backgroundColor(this.selectedFormat === 'ts' ? '#007DFF' : '#999999')
                .enabled(!this.isConverting)
                .onClick(() => {
                  this.convertToFormat('ts');
                })
            }
            .width('100%')
            .margin({ bottom: 8 })

            // 音频格式按钮
            Row() {
              Button('提取 MP3 🎵')
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .backgroundColor(this.selectedFormat === 'mp3' ? '#007DFF' : '#999999')
                .enabled(!this.isConverting)
                .onClick(() => {
                  this.convertToFormat('mp3');
                })

              Button('提取 AAC 🎵')
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .margin({ left: 8 })
                .backgroundColor(this.selectedFormat === 'aac' ? '#007DFF' : '#999999')
                .enabled(!this.isConverting)
                .onClick(() => {
                  this.convertToFormat('aac');
                })
            }
            .width('100%')

            Divider()
              .margin({ top: 16, bottom: 16 })
              .color('#E5E5E5')

            Row() {
              Button('取消任务')
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .backgroundColor('#FF6B6B')
                .enabled(this.isConverting)
                .onClick(() => {
                  this.cancelConvert();
                })

              Button('重置计时')
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .margin({ left: 8 })
                .backgroundColor('#007DFF')
                .onClick(() => {
                  this.singleTaskTime = '--';
                  this.formatConvertTime = '--';
                  this.addLog('⏱️ 计时已重置');
                })

              Button('清空日志')
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .margin({ left: 8 })
                .backgroundColor('#999999')
                .onClick(() => {
                  this.clearLogs();
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .margin({ top: 12, left: 16, right: 16 })

          // 日志区域
          Column() {
            Row() {
              Text('执行日志')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)

              Text(`${this.logs.length} 条`)
                .fontSize(12)
                .fontColor('#999999')
            }
            .width('100%')
            .margin({ bottom: 8 })

            Scroll() {
              Column() {
                ForEach(this.logs, (log: string, index: number) => {
                  Text(log)
                    .fontSize(12)
                    .fontColor('#333333')
                    .width('100%')
                    .margin({ bottom: 4 })
                    .fontFamily('monospace')
                }, (log: string, index: number) => `${index}_${log}`)
              }
            }
            .scrollable(ScrollDirection.Vertical)
            .scrollBar(BarState.Auto)
            .height(300)
            .backgroundColor('#F5F5F5')
            .padding(8)
            .borderRadius(4)
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .margin({ top: 12, left: 16, right: 16, bottom: 16 })
        }
      }
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
  }
}
