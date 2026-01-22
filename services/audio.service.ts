/**
 * 音频录制服务
 * 使用 MediaRecorder API
 */

export interface AudioRecordingOptions {
  mimeType?: string
  audioBitsPerSecond?: number
}

export class AudioService {
  private mediaRecorder: MediaRecorder | null = null
  private audioChunks: Blob[] = []
  private stream: MediaStream | null = null
  private startTime: number = 0

  /**
   * 开始录音
   */
  async startRecording(options?: AudioRecordingOptions): Promise<void> {
    try {
      // 请求麦克风权限
      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        }
      })

      // 选择支持的 MIME 类型
      const mimeType = this.getSupportedMimeType(options?.mimeType)

      // 创建 MediaRecorder
      this.mediaRecorder = new MediaRecorder(this.stream, {
        mimeType,
        audioBitsPerSecond: options?.audioBitsPerSecond || 128000
      })

      // 清空之前的音频片段
      this.audioChunks = []

      // 监听数据可用事件
      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.audioChunks.push(event.data)
        }
      }

      // 开始录音
      this.mediaRecorder.start()
      this.startTime = Date.now()

      console.log('🎤 Recording started')
    } catch (error) {
      console.error('❌ Failed to start recording:', error)
      throw new Error('无法访问麦克风，请检查权限设置')
    }
  }

  /**
   * 停止录音并返回音频 Blob
   */
  async stopRecording(): Promise<Blob> {
    return new Promise((resolve, reject) => {
      if (!this.mediaRecorder) {
        reject(new Error('录音未开始'))
        return
      }

      this.mediaRecorder.onstop = () => {
        const mimeType = this.mediaRecorder?.mimeType || 'audio/webm'
        const audioBlob = new Blob(this.audioChunks, { type: mimeType })

        // 停止所有音频轨道
        if (this.stream) {
          this.stream.getTracks().forEach(track => track.stop())
        }

        console.log('🎤 Recording stopped', {
          size: audioBlob.size,
          type: audioBlob.type,
          duration: this.getDuration()
        })

        resolve(audioBlob)
      }

      this.mediaRecorder.stop()
    })
  }

  /**
   * 取消录音
   */
  cancelRecording(): void {
    if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
      this.mediaRecorder.stop()
    }

    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
    }

    this.audioChunks = []
    console.log('🎤 Recording cancelled')
  }

  /**
   * 获取录音时长（秒）
   */
  getDuration(): number {
    if (this.startTime === 0) return 0
    return Math.floor((Date.now() - this.startTime) / 1000)
  }

  /**
   * 获取录音状态
   */
  getState(): 'inactive' | 'recording' | 'paused' {
    return this.mediaRecorder?.state || 'inactive'
  }

  /**
   * 获取支持的 MIME 类型
   */
  private getSupportedMimeType(preferred?: string): string {
    const types = [
      preferred,
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/mp4'
    ].filter(Boolean) as string[]

    for (const type of types) {
      if (MediaRecorder.isTypeSupported(type)) {
        return type
      }
    }

    // 默认返回空字符串，让浏览器自动选择
    return ''
  }

  /**
   * 将 Blob 转换为 Base64（用于 API 传输）
   */
  async blobToBase64(blob: Blob): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onloadend = () => {
        const base64 = reader.result as string
        // 移除 data:audio/webm;base64, 前缀
        const base64Data = base64.split(',')[1]
        resolve(base64Data)
      }
      reader.onerror = reject
      reader.readAsDataURL(blob)
    })
  }

  /**
   * 获取音频文件的实际时长（通过创建 Audio 元素）
   */
  async getAudioDuration(blob: Blob): Promise<number> {
    return new Promise((resolve, reject) => {
      const audio = new Audio()
      audio.src = URL.createObjectURL(blob)

      audio.onloadedmetadata = () => {
        URL.revokeObjectURL(audio.src)
        resolve(Math.floor(audio.duration))
      }

      audio.onerror = () => {
        URL.revokeObjectURL(audio.src)
        reject(new Error('无法读取音频时长'))
      }
    })
  }

  /**
   * 检查麦克风权限
   */
  async checkMicrophonePermission(): Promise<boolean> {
    try {
      const result = await navigator.permissions.query({ name: 'microphone' as PermissionName })
      return result.state === 'granted'
    } catch (error) {
      // 如果 permissions API 不支持，尝试直接请求
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
        stream.getTracks().forEach(track => track.stop())
        return true
      } catch {
        return false
      }
    }
  }
}

// 导出单例实例
export const audioService = new AudioService()
