/**
 * FFmpeg 功能测试页面
 * 测试视频下载和转换功能
 *
 * 注意：FFmpeg 内部使用全局变量，不支持多线程并发执行
 * 多个任务会串行执行（队列模式）
 */

import { buffer } from '@kit.ArkTS';
import { FFmpegManager, FFmpegFactory, FFmpegCommandBuilder, TaskCallback, FLog, ContainerFormat, FFMpegUtils } from 'lib_ffmpeg_utils';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { ImageConverter, ImageFactory, ImageFormat } from 'lib_image_convert';

// 转换格式类型
type ConvertFormat = 'mp4' | 'flv' | 'avi' | 'mkv' | 'ts' | 'mp3' | 'aac';
type ImageFormatType = 'jpg' | 'png' | 'bmp' | 'webp' | 'gif' | 'heif';

@Entry
@Component
struct Index {
  // 测试视频 URL (base64 编码)
  static TEST_VIDEO_URL: string = buffer.from(
    'aHR0cHM6Ly9zbnMtdmlkZW8tYWwueGhzY2RuLmNvbS9zdHJlYW0vMTEwLzQwNS8wMWU1ODNjYjZlMGZlZDVhMDEwMzcwMDM4YzhhZDk2MmZiXzQwNS5tcDQ=',
    'base64'
  ).toString('binary');

  @State convertProgress: number = 0;
  @State statusText: string = '准备就绪';
  @State isConverting: boolean = false;
  @State logs: string[] = [];

  // 耗时统计
  @State copyTime: string = '--';
  @State formatTime: string = '--';
  @State hwTime: string = '--';
  @State selectedFormat: ConvertFormat = 'flv';

  private outputFilePath: string = '';
  private taskId: string = '';
  @State watermarkPath: string = '';
  @State selectedImagePath: string = '';
  @State selectedImageFormat: ImageFormatType = 'png';
  @State imageConvertTime: string = '--';
  @State selectedVideoPath: string = ''; // 用户选择的视频路径

  aboutToAppear(): void {
    // 默认开启 native 层日志
    // FFMpegUtils.showLog(true);
    //
    this.addLog('FFmpeg 测试页面初始化');
    this.addLog('⚠️ FFmpeg 不支持多线程并发，任务串行执行');
    this.addLog('🔧 硬件加速: h264_ohosavcodec');
    this.addLog('📝 Native 日志已开启');
    this.addLog('🖼️ 支持图片格式转换: JPG/PNG/WEBP/BMP/GIF/HEIF (@prq/image-converter)');
    this.outputFilePath = getContext().filesDir + '/test_output.mp4';
  }

  /** 从图库选择图片进行格式转换 */
  async selectImageForConvert(): Promise<boolean> {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris.length > 0) {
        const uri = result.photoUris[0];
        // 复制到应用沙箱目录
        const destPath = getContext().filesDir + '/image_to_convert.tmp';
        const srcFile = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
        const destFile = fileIo.openSync(destPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        const buf = new ArrayBuffer(4096);
        let readLen = fileIo.readSync(srcFile.fd, buf);
        while (readLen > 0) {
          fileIo.writeSync(destFile.fd, buf, { length: readLen });
          readLen = fileIo.readSync(srcFile.fd, buf);
        }
        fileIo.closeSync(srcFile);
        fileIo.closeSync(destFile);
        this.selectedImagePath = destPath;
        this.addLog(`✅ 已选择图片: ${uri}`);
        return true;
      }
      return false;
    } catch (error) {
      this.addLog(`❌ 选择图片失败: ${error}`);
      return false;
    }
  }

  /** 从视频库选择视频 */
  async selectVideo(): Promise<boolean> {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris.length > 0) {
        const uri = result.photoUris[0];
        // 复制到应用沙箱目录
        const destPath = getContext().filesDir + '/selected_video.mp4';
        this.addLog('📹 正在复制视频文件...');
        const srcFile = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
        const destFile = fileIo.openSync(destPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        const buf = new ArrayBuffer(1024 * 1024); // 1MB 缓冲区
        let readLen = fileIo.readSync(srcFile.fd, buf);
        while (readLen > 0) {
          fileIo.writeSync(destFile.fd, buf, { length: readLen });
          readLen = fileIo.readSync(srcFile.fd, buf);
        }
        fileIo.closeSync(srcFile);
        fileIo.closeSync(destFile);
        this.selectedVideoPath = destPath;
        const stat = fileIo.statSync(destPath);
        this.addLog(`✅ 已选择视频: ${(stat.size / 1024 / 1024).toFixed(2)} MB`);
        return true;
      }
      return false;
    } catch (error) {
      this.addLog(`❌ 选择视频失败: ${error}`);
      return false;
    }
  }

  /** 图片格式转换（使用 lib_image_convert 库） */
  async testImageConvert(format: ImageFormatType): Promise<void> {
    if (this.isConverting) return;

    // 如果没有选择图片，先让用户选择
    if (this.selectedImagePath === '') {
      this.addLog('🖼️ 请先选择图片...');
      const selected = await this.selectImageForConvert();
      if (!selected) {
        this.addLog('⚠️ 未选择图片，取消操作');
        return;
      }
    }

    this.isConverting = true;
    this.convertProgress = 0;
    this.imageConvertTime = '计时中...';
    this.selectedImageFormat = format;
    this.statusText = `转换图片为 ${format.toUpperCase()}...`;
    this.addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    this.addLog(`🖼️ 图片格式转换 (@prq/image-converter): → ${format.toUpperCase()}`);

    const startTime = Date.now();
    const output = getContext().filesDir + `/converted_image.${format}`;

    try {
      // 使用 ImageFactory 快捷方法（更简单）
      switch (format) {
        case 'jpg':
          this.addLog('📝 使用 ImageFactory.toJpeg()');
          await ImageFactory.toJpeg(this.selectedImagePath, output, 90);
          break;
        case 'png':
          this.addLog('📝 使用 ImageFactory.toPng()');
          await ImageFactory.toPng(this.selectedImagePath, output);
          break;
        case 'webp':
          this.addLog('📝 使用 ImageFactory.toWebp()');
          await ImageFactory.toWebp(this.selectedImagePath, output, 90);
          break;
        case 'bmp':
          this.addLog('📝 使用 ImageFactory.toBmp()');
          await ImageFactory.toBmp(this.selectedImagePath, output);
          break;
        case 'gif':
          this.addLog('📝 使用 ImageFactory.toGif()');
          await ImageFactory.toGif(this.selectedImagePath, output);
          break;
        case 'heif':
          this.addLog('📝 使用 ImageFactory.toHeif()');
          await ImageFactory.toHeif(this.selectedImagePath, output, 90);
          break;
        default:
          await ImageFactory.toJpeg(this.selectedImagePath, output, 90);
      }

      const duration = ((Date.now() - startTime) / 1000).toFixed(2);
      this.statusText = '✅ 完成';
      this.addLog(`✅ 成功！耗时: ${duration}s`);
      this.imageConvertTime = `${duration}s`;
      this.checkOutputFile(output);
      this.addLog(`💾 输出路径: ${output}`);
      this.isConverting = false;
    } catch (error) {
      this.statusText = '❌ 失败';
      this.addLog(`❌ 转换失败: ${error}`);
      this.imageConvertTime = '失败';
      this.isConverting = false;
    }
  }

  /** 从图库选择水印图片 */
  async selectWatermark(): Promise<boolean> {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris.length > 0) {
        const uri = result.photoUris[0];
        // 复制到应用沙箱目录
        const destPath = getContext().filesDir + '/watermark_selected.png';
        const srcFile = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
        const destFile = fileIo.openSync(destPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        const buf = new ArrayBuffer(4096);
        let readLen = fileIo.readSync(srcFile.fd, buf);
        while (readLen > 0) {
          fileIo.writeSync(destFile.fd, buf, { length: readLen });
          readLen = fileIo.readSync(srcFile.fd, buf);
        }
        fileIo.closeSync(srcFile);
        fileIo.closeSync(destFile);
        this.watermarkPath = destPath;
        this.addLog(`✅ 已选择水印: ${uri}`);
        return true;
      }
      return false;
    } catch (error) {
      this.addLog(`❌ 选择水印失败: ${error}`);
      return false;
    }
  }

  addLog(message: string): void {
    const timestamp = new Date().toLocaleTimeString();
    const logMessage = `[${timestamp}] ${message}`;
    this.logs.push(logMessage);
    console.log(logMessage);
    FLog.info('FFmpegTest', message);
    if (this.logs.length > 50) {
      this.logs.shift();
    }
  }

  checkOutputFile(path: string): void {
    try {
      const stat = fileIo.statSync(path);
      this.addLog(`✅ 输出文件: ${(stat.size / 1024).toFixed(2)} KB`);
    } catch (error) {
      this.addLog(`⚠️ 无法读取输出文件: ${error}`);
    }
  }

  // ============================================================
  // 零拷贝测试
  // ============================================================

  /** MP4 复制 */
  testCopy(): void {
    if (this.isConverting) return;
    this.isConverting = true;
    this.convertProgress = 0;
    this.copyTime = '计时中...';
    this.statusText = '开始 MP4 复制...';
    this.addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    this.addLog('🚀 MP4 复制（零拷贝）');

    const startTime = Date.now();
    const output = getContext().filesDir + '/copy_output.mp4';
    const cmd = FFmpegFactory.remux(Index.TEST_VIDEO_URL, output, ContainerFormat.MP4);
    this.addLog(`命令: ${cmd.join(' ')}`);

    this.executeTask(cmd, startTime, (duration: string): void => {
      this.copyTime = duration;
      this.checkOutputFile(output);
    });
  }

  /** 格式转换 */
  testFormat(format: ConvertFormat): void {
    if (this.isConverting) return;
    this.isConverting = true;
    this.convertProgress = 0;
    this.formatTime = '计时中...';
    this.selectedFormat = format;
    this.statusText = `转换为 ${format.toUpperCase()}...`;
    this.addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    this.addLog(`🚀 格式转换: MP4 → ${format.toUpperCase()}`);

    const startTime = Date.now();
    const output = getContext().filesDir + `/output.${format}`;
    let cmd: string[];

    switch (format) {
      case 'flv':
        cmd = FFmpegFactory.remux(Index.TEST_VIDEO_URL, output, ContainerFormat.FLV);
        break;
      case 'avi':
        cmd = FFmpegFactory.remux(Index.TEST_VIDEO_URL, output, ContainerFormat.AVI);
        break;
      case 'mkv':
        cmd = FFmpegFactory.remux(Index.TEST_VIDEO_URL, output, ContainerFormat.MKV);
        break;
      case 'ts':
        cmd = FFmpegFactory.remux(Index.TEST_VIDEO_URL, output, ContainerFormat.TS);
        break;
      case 'mp3':
      case 'aac':
        cmd = FFmpegFactory.extractAudio(Index.TEST_VIDEO_URL, output);
        break;
      default:
        cmd = FFmpegFactory.remux(Index.TEST_VIDEO_URL, output, ContainerFormat.MP4);
    }

    this.addLog(`命令: ${cmd.join(' ')}`);
    this.executeTask(cmd, startTime, (duration: string): void => {
      this.formatTime = duration;
      this.checkOutputFile(output);
    });
  }

  // ============================================================
  // 硬解硬编测试
  // ============================================================

  /** 视频缩放（硬解硬编） */
  async testScale(): Promise<void> {
    if (this.isConverting) return;

    // 如果没有选择视频，先让用户选择
    if (this.selectedVideoPath === '') {
      this.addLog('📹 请先选择视频...');
      const selected = await this.selectVideo();
      if (!selected) {
        this.addLog('⚠️ 未选择视频，使用默认测试视频');
        this.selectedVideoPath = Index.TEST_VIDEO_URL;
      }
    }

    this.isConverting = true;
    this.convertProgress = 0;
    this.hwTime = '计时中...';
    this.statusText = '🚀 硬解硬编缩放...';
    this.addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    this.addLog('🔧 视频缩放（硬解硬编）');

    const startTime = Date.now();
    const output = getContext().filesDir + '/scale_720p.mp4';
    const cmd = FFmpegFactory.scale(this.selectedVideoPath, output, 1280, 720);
    this.addLog(`命令: ${cmd.join(' ')}`);

    this.executeTask(cmd, startTime, (duration: string): void => {
      this.hwTime = duration;
      this.checkOutputFile(output);
    });
  }

  /** 视频转码（硬解硬编） */
  async testTranscode(): Promise<void> {
    if (this.isConverting) return;

    // 如果没有选择视频，先让用户选择
    if (this.selectedVideoPath === '') {
      this.addLog('📹 请先选择视频...');
      const selected = await this.selectVideo();
      if (!selected) {
        this.addLog('⚠️ 未选择视频，使用默认测试视频');
        this.selectedVideoPath = Index.TEST_VIDEO_URL;
      }
    }

    this.isConverting = true;
    this.convertProgress = 0;
    this.hwTime = '计时中...';
    this.statusText = '🚀 硬解硬编转码...';
    this.addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    this.addLog('🔧 视频转码（硬解硬编 2Mbps）');

    const startTime = Date.now();
    const output = getContext().filesDir + '/transcode_2m.mp4';
    const cmd = FFmpegFactory.transcode(this.selectedVideoPath, output, '2M');
    this.addLog(`命令: ${cmd.join(' ')}`);

    this.executeTask(cmd, startTime, (duration: string): void => {
      this.hwTime = duration;
      this.checkOutputFile(output);
    });
  }

  /** 添加水印（硬解硬编） */
  async testWatermark(): Promise<void> {
    if (this.isConverting) return;

    // 如果没有选择水印，先让用户选择
    if (this.watermarkPath === '') {
      this.addLog('📷 请先选择水印图片...');
      const selected = await this.selectWatermark();
      if (!selected) {
        this.addLog('⚠️ 未选择水印图片，取消操作');
        return;
      }
    }

    this.isConverting = true;
    this.convertProgress = 0;
    this.hwTime = '计时中...';
    this.statusText = '🚀 硬解硬编水印...';
    this.addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    this.addLog('🔧 添加水印（硬解硬编）');

    const startTime = Date.now();
    const output = getContext().filesDir + '/watermark_output.mp4';
    const cmd = FFmpegFactory.watermark(Index.TEST_VIDEO_URL, this.watermarkPath, output);
    this.addLog(`命令: ${cmd.join(' ')}`);

    this.executeTask(cmd, startTime, (duration: string): void => {
      this.hwTime = duration;
      this.checkOutputFile(output);
    });
  }

  /** 视频裁剪（时间裁剪） */
  testCut(): void {
    if (this.isConverting) return;
    this.isConverting = true;
    this.convertProgress = 0;
    this.hwTime = '计时中...';
    this.statusText = '✂️ 视频裁剪...';
    this.addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    this.addLog('✂️ 视频裁剪（零拷贝）');

    const startTime = Date.now();
    const output = getContext().filesDir + '/cut_30s.mp4';
    const cmd = FFmpegFactory.cut(Index.TEST_VIDEO_URL, output, '00:00:10', '30');
    this.addLog(`命令: ${cmd.join(' ')}`);

    this.executeTask(cmd, startTime, (duration: string): void => {
      this.hwTime = duration;
      this.checkOutputFile(output);
    });
  }

  /** 视频画面裁剪（crop + 硬编码） */
  async testVideoCrop(): Promise<void> {
    if (this.isConverting) return;

    // 如果没有选择视频，先让用户选择
    if (this.selectedVideoPath === '') {
      this.addLog('📹 请先选择视频...');
      const selected = await this.selectVideo();
      if (!selected) {
        this.addLog('⚠️ 未选择视频，取消操作');
        return;
      }
    }

    this.isConverting = true;
    this.convertProgress = 0;
    this.hwTime = '计时中...';
    this.statusText = '✂️ 裁剪画面（左上角）...';
    this.addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    this.addLog('✂️ 视频画面裁剪（crop + 硬编码）');
    this.addLog('📐 裁剪区域: 左上角 640x360');

    const startTime = Date.now();
    const output = getContext().filesDir + '/crop_output.mp4';
    
    // 裁剪左上角 640x360 区域（从 0,0 开始）
    const cmd = FFmpegFactory.videoCrop(this.selectedVideoPath, output, 640, 360, 0, 0);
    
    this.addLog(`命令: ${cmd.join(' ')}`);
    this.addLog('⚙️ 流程: 硬解码 → crop滤镜(CPU) → 硬编码');

    this.executeTask(cmd, startTime, (duration: string): void => {
      this.hwTime = duration;
      this.checkOutputFile(output);
      this.addLog('💡 提示: crop滤镜在CPU执行，但解码和编码使用硬件加速');
    });
  }

  /** Builder 自定义命令 */
  testBuilder(): void {
    if (this.isConverting) return;
    this.isConverting = true;
    this.convertProgress = 0;
    this.hwTime = '计时中...';
    this.statusText = '🛠️ Builder 自定义...';
    this.addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    this.addLog('🛠️ Builder 自定义命令');

    const startTime = Date.now();
    const output = getContext().filesDir + '/builder_output.mp4';

    const cmd = new FFmpegCommandBuilder()
      .input(Index.TEST_VIDEO_URL)
      .hwaccel()
      .scale(1280, 720)
      .fps(30)
      .videoBitrate('2M')
      .audioCodec('aac')
      .audioBitrate('128k')
      .output(output)
      .build();

    this.addLog(`命令: ${cmd.join(' ')}`);

    this.executeTask(cmd, startTime, (duration: string): void => {
      this.hwTime = duration;
      this.checkOutputFile(output);
    });
  }

  // ============================================================
  // 通用执行方法
  // ============================================================

  executeTask(cmd: string[], startTime: number, onComplete: (duration: string) => void): void {
    try {
      this.taskId = FFmpegManager.getInstance().execute(cmd, 180000, Object({
        onStart: (): void => {
          this.addLog('🎬 任务已启动');
        },
        onProgress: (progress: number): void => {
          this.convertProgress = progress * 100;
          this.statusText = `进度: ${this.convertProgress.toFixed(1)}%`;
        },
        onSuccess: (): void => {
          const duration = ((Date.now() - startTime) / 1000).toFixed(2);
          this.statusText = '✅ 完成';
          this.addLog(`✅ 成功！耗时: ${duration}s`);
          onComplete(`${duration}s`);
          this.isConverting = false;
        },
        onFailure: (): void => {
          this.statusText = '❌ 失败';
          this.addLog('❌ 任务失败');
          onComplete('失败');
          this.isConverting = false;
        }
      }) as TaskCallback);
      this.addLog(`任务ID: ${this.taskId}`);
    } catch (error) {
      this.statusText = '❌ 执行错误';
      this.addLog(`❌ 错误: ${error}`);
      this.isConverting = false;
    }
  }

  cancelTask(): void {
    if (this.taskId) {
      const success = FFmpegManager.getInstance().cancel(this.taskId);
      this.addLog(success ? '🚫 已取消' : '⚠️ 取消失败');
    }
  }

  clearLogs(): void {
    this.logs = [];
    this.addLog('日志已清空');
  }

  resetTime(): void {
    this.copyTime = '--';
    this.formatTime = '--';
    this.hwTime = '--';
    this.imageConvertTime = '--';
    this.addLog('⏱️ 计时已重置');
  }

  // ============================================================
  // UI
  // ============================================================

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

            // 耗时统计
            Row() {
              Column() {
                Text('复制耗时')
                  .fontSize(12)
                  .fontColor('#999999')
                Text(this.copyTime)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FF9900')
              }.layoutWeight(1)

              Divider().vertical(true).height(40).color('#E5E5E5')

              Column() {
                Text(`转${this.selectedFormat.toUpperCase()}`)
                  .fontSize(12)
                  .fontColor('#999999')
                Text(this.formatTime)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#007DFF')
              }.layoutWeight(1)

              Divider().vertical(true).height(40).color('#E5E5E5')

              Column() {
                Text('硬解硬编')
                  .fontSize(12)
                  .fontColor('#999999')
                Text(this.hwTime)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#4CAF50')
              }.layoutWeight(1)

              Divider().vertical(true).height(40).color('#E5E5E5')

              Column() {
                Text('图片转换')
                  .fontSize(12)
                  .fontColor('#999999')
                Text(this.imageConvertTime)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#E91E63')
              }.layoutWeight(1)
            }
            .width('100%')
            .padding(8)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .margin({ bottom: 12 })

            // 进度条
            Row() {
              Text('进度:').fontSize(14).width(50)
              Progress({ value: this.convertProgress, total: 100, type: ProgressType.Linear }).width('60%')
              Text(`${this.convertProgress.toFixed(1)}%`).fontSize(12).margin({ left: 8 })
            }.width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .margin({ top: 12, left: 16, right: 16 })

          // 零拷贝操作
          Column() {
            Text('零拷贝（最快）')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .margin({ bottom: 8 })

            Button('MP4 复制 ⚡️')
              .width('100%')
              .height(44)
              .backgroundColor('#FF9900')
              .enabled(!this.isConverting)
              .onClick((): void => this.testCopy())

            Row() {
              Button('FLV').layoutWeight(1).height(40).backgroundColor(this.selectedFormat === 'flv' ? '#007DFF' : '#999999').enabled(!this.isConverting).onClick((): void => this.testFormat('flv'))
              Button('AVI').layoutWeight(1).height(40).margin({ left: 8 }).backgroundColor(this.selectedFormat === 'avi' ? '#007DFF' : '#999999').enabled(!this.isConverting).onClick((): void => this.testFormat('avi'))
              Button('MKV').layoutWeight(1).height(40).margin({ left: 8 }).backgroundColor(this.selectedFormat === 'mkv' ? '#007DFF' : '#999999').enabled(!this.isConverting).onClick((): void => this.testFormat('mkv'))
              Button('TS').layoutWeight(1).height(40).margin({ left: 8 }).backgroundColor(this.selectedFormat === 'ts' ? '#007DFF' : '#999999').enabled(!this.isConverting).onClick((): void => this.testFormat('ts'))
            }.width('100%').margin({ top: 8 })

            Row() {
              Button('提取音频 🎵').layoutWeight(1).height(40).backgroundColor('#999999').enabled(!this.isConverting).onClick((): void => this.testFormat('aac'))
              Button('裁剪 30s ✂️').layoutWeight(1).height(40).margin({ left: 8 }).backgroundColor('#999999').enabled(!this.isConverting).onClick((): void => this.testCut())
            }.width('100%').margin({ top: 8 })

            Divider().margin({ top: 16, bottom: 16 }).color('#E5E5E5')

            // 硬解硬编操作
            Text('🔧 硬解硬编（h264_ohosavcodec）')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .margin({ bottom: 8 })

            Button(this.selectedVideoPath === '' ? '选择视频 📹' : '已选择视频 ✅')
              .width('100%')
              .height(44)
              .backgroundColor(this.selectedVideoPath === '' ? '#673AB7' : '#4CAF50')
              .enabled(!this.isConverting)
              .onClick((): void => { this.selectVideo(); })
              .margin({ bottom: 8 })

            Row() {
              Button('缩放 720p 🚀').layoutWeight(1).height(40).backgroundColor('#4CAF50').enabled(!this.isConverting).onClick((): void => { this.testScale(); })
              Button('转码 2M 🚀').layoutWeight(1).height(40).margin({ left: 8 }).backgroundColor('#2196F3').enabled(!this.isConverting).onClick((): void => { this.testTranscode(); })
            }.width('100%')

            Row() {
              Button('裁剪画面 ✂️').layoutWeight(1).height(40).backgroundColor('#FF9800').enabled(!this.isConverting).onClick((): void => { this.testVideoCrop(); })
              Button('Builder 🛠️').layoutWeight(1).height(40).margin({ left: 8 }).backgroundColor('#FF5722').enabled(!this.isConverting).onClick((): void => this.testBuilder())
            }.width('100%').margin({ top: 8 })

            Row() {
              Button(this.watermarkPath === '' ? '选择水印 📷' : '添加水印 🚀').layoutWeight(1).height(40).backgroundColor('#9C27B0').enabled(!this.isConverting).onClick((): void => { this.testWatermark(); })
            }.width('100%').margin({ top: 8 })

            Divider().margin({ top: 16, bottom: 16 }).color('#E5E5E5')

            // 图片格式转换
            Text('🖼️ 图片格式转换')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .margin({ bottom: 8 })

            Button(this.selectedImagePath === '' ? '选择图片 📷' : '已选择图片 ✅')
              .width('100%')
              .height(44)
              .backgroundColor(this.selectedImagePath === '' ? '#E91E63' : '#4CAF50')
              .enabled(!this.isConverting)
              .onClick((): void => { this.selectImageForConvert(); })

            Row() {
              Button('JPG').layoutWeight(1).height(40).backgroundColor(this.selectedImageFormat === 'jpg' ? '#E91E63' : '#999999').enabled(!this.isConverting).onClick((): void => { this.testImageConvert('jpg'); })
              Button('PNG').layoutWeight(1).height(40).margin({ left: 8 }).backgroundColor(this.selectedImageFormat === 'png' ? '#E91E63' : '#999999').enabled(!this.isConverting).onClick((): void => { this.testImageConvert('png'); })
            }.width('100%').margin({ top: 8 })

            Row() {
              Button('WEBP').layoutWeight(1).height(40).backgroundColor(this.selectedImageFormat === 'webp' ? '#E91E63' : '#999999').enabled(!this.isConverting).onClick((): void => { this.testImageConvert('webp'); })
              Button('GIF').layoutWeight(1).height(40).margin({ left: 8 }).backgroundColor(this.selectedImageFormat === 'gif' ? '#E91E63' : '#999999').enabled(!this.isConverting).onClick((): void => { this.testImageConvert('gif'); })
              Button('HEIF').layoutWeight(1).height(40).margin({ left: 8 }).backgroundColor(this.selectedImageFormat === 'heif' ? '#E91E63' : '#999999').enabled(!this.isConverting).onClick((): void => { this.testImageConvert('heif'); })
            }.width('100%').margin({ top: 8 })

            Divider().margin({ top: 16, bottom: 16 }).color('#E5E5E5')

            // 控制按钮
            Row() {
              Button('取消').layoutWeight(1).height(40).backgroundColor('#FF6B6B').enabled(this.isConverting).onClick((): void => this.cancelTask())
              Button('重置').layoutWeight(1).height(40).margin({ left: 8 }).backgroundColor('#007DFF').onClick((): void => this.resetTime())
              Button('清空').layoutWeight(1).height(40).margin({ left: 8 }).backgroundColor('#999999').onClick((): void => this.clearLogs())
            }.width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .margin({ top: 12, left: 16, right: 16 })

          // 日志区域
          Column() {
            Row() {
              Text('执行日志').fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1)
              Text(`${this.logs.length} 条`).fontSize(12).fontColor('#999999')
            }.width('100%').margin({ bottom: 8 })

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
            .height(250)
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
