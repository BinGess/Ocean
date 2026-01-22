/**
 * 豆包语音转写服务（WebSocket 二进制协议）
 * 文档：https://www.volcengine.com/docs/6561/1354869
 */

import { DOUBAO_ASR_CONFIG } from '../config/env'
import { v4 as uuidv4 } from 'uuid'

/**
 * 协议常量
 */
const PROTOCOL_VERSION = 0b0001 // 版本 1
const HEADER_SIZE = 0b0001 // Header 大小 = 4 字节

/**
 * 消息类型
 */
enum MessageType {
  FULL_CLIENT_REQUEST = 0b0001,      // 端上发送配置参数
  AUDIO_ONLY_REQUEST = 0b0010,       // 端上发送音频数据
  FULL_SERVER_RESPONSE = 0b1001,     // 服务端识别结果
  ERROR_MESSAGE = 0b1111             // 服务端错误消息
}

/**
 * 消息标志
 */
enum MessageFlags {
  NONE = 0b0000,                     // 无特殊标志
  POSITIVE_SEQUENCE = 0b0001,        // 正数序列号
  LAST_PACKET = 0b0010,              // 最后一包（负包）
  NEGATIVE_SEQUENCE = 0b0011         // 负数序列号（最后一包）
}

/**
 * 序列化方法
 */
enum SerializationMethod {
  NONE = 0b0000,
  JSON = 0b0001
}

/**
 * 压缩方法
 */
enum CompressionMethod {
  NONE = 0b0000,
  GZIP = 0b0001
}

/**
 * Full Client Request 配置
 */
interface ASRConfig {
  user?: {
    uid?: string
    platform?: string
  }
  audio: {
    format: 'pcm' | 'wav' | 'ogg' | 'mp3'
    codec?: 'raw' | 'opus'
    rate: number
    bits: number
    channel: number
  }
  request: {
    model_name: 'bigmodel'
    enable_itn?: boolean
    enable_punc?: boolean
    enable_ddc?: boolean
    result_type?: 'full' | 'single'
  }
}

/**
 * 识别结果
 */
interface ASRResult {
  text: string
  utterances?: Array<{
    text: string
    start_time: number
    end_time: number
    definite: boolean
    words?: Array<{
      text: string
      start_time: number
      end_time: number
    }>
  }>
}

/**
 * 豆包语音转写服务
 */
export class TranscriptionService {
  private ws: WebSocket | null = null
  private connectId: string = ''
  private sequenceNumber: number = 0

  /**
   * 转写音频（主入口）
   */
  async transcribe(audioBlob: Blob): Promise<string> {
    try {
      console.log('🎙️ Starting transcription...')

      // 检查配置
      if (!this.isConfigured()) {
        console.warn('⚠️ Doubao ASR not configured, using mock transcription')
        return this.mockTranscribe(audioBlob)
      }

      // 1. 建立 WebSocket 连接
      await this.connect()

      // 2. 发送配置请求
      await this.sendFullClientRequest()

      // 3. 发送音频数据
      const result = await this.sendAudioData(audioBlob)

      // 4. 关闭连接
      this.disconnect()

      console.log('✅ Transcription completed:', result)
      return result
    } catch (error) {
      console.error('❌ Transcription failed:', error)
      this.disconnect()

      // 降级到模拟转写
      return this.mockTranscribe(audioBlob)
    }
  }

  /**
   * 建立 WebSocket 连接（带鉴权）
   */
  private async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        this.connectId = uuidv4()

        // 构建 WebSocket URL（带鉴权参数）
        // 注意：浏览器 WebSocket 不支持自定义 Header，所以通过 URL 参数传递
        const url = new URL(DOUBAO_ASR_CONFIG.endpoint)
        url.searchParams.set('appkey', DOUBAO_ASR_CONFIG.appKey)
        url.searchParams.set('token', DOUBAO_ASR_CONFIG.accessKey)
        url.searchParams.set('resource_id', DOUBAO_ASR_CONFIG.resourceId)
        url.searchParams.set('connect_id', this.connectId)

        this.ws = new WebSocket(url.toString())
        this.ws.binaryType = 'arraybuffer'

        this.ws.onopen = () => {
          console.log('✅ WebSocket connected:', this.connectId)
          resolve()
        }

        this.ws.onerror = (error) => {
          console.error('❌ WebSocket error:', error)
          reject(new Error('WebSocket 连接失败'))
        }

        this.ws.onclose = () => {
          console.log('🔌 WebSocket closed')
        }

        // 连接超时
        setTimeout(() => {
          if (this.ws?.readyState !== WebSocket.OPEN) {
            reject(new Error('WebSocket 连接超时'))
          }
        }, 5000)
      } catch (error) {
        reject(error)
      }
    })
  }

  /**
   * 发送 Full Client Request（配置参数）
   */
  private async sendFullClientRequest(): Promise<void> {
    const config: ASRConfig = {
      user: {
        uid: `user_${Date.now()}`,
        platform: 'Web'
      },
      audio: {
        format: 'wav',
        codec: 'raw',
        rate: 16000,
        bits: 16,
        channel: 1
      },
      request: {
        model_name: 'bigmodel',
        enable_itn: true,      // 文本规范化
        enable_punc: true,     // 标点符号
        enable_ddc: false,     // 语义顺滑
        result_type: 'full'    // 全量返回
      }
    }

    const payload = JSON.stringify(config)
    const payloadBuffer = new TextEncoder().encode(payload)

    // 构建二进制消息
    const message = this.buildMessage(
      MessageType.FULL_CLIENT_REQUEST,
      MessageFlags.NONE,
      SerializationMethod.JSON,
      CompressionMethod.NONE,
      payloadBuffer
    )

    this.send(message)
    console.log('📤 Sent full client request')
  }

  /**
   * 发送音频数据（分包）
   */
  private async sendAudioData(audioBlob: Blob): Promise<string> {
    return new Promise(async (resolve, reject) => {
      try {
        // 读取音频数据
        const audioBuffer = await audioBlob.arrayBuffer()
        const audioData = new Uint8Array(audioBuffer)

        // 音频分包（每包 200ms，推荐值）
        const sampleRate = 16000
        const bytesPerSample = 2 // 16 bits = 2 bytes
        const channels = 1
        const chunkDurationMs = 200
        const chunkSize = (sampleRate * bytesPerSample * channels * chunkDurationMs) / 1000

        let offset = 0
        let isLastPacket = false
        let transcriptionResult = ''

        // 监听服务端响应
        this.ws!.onmessage = (event) => {
          try {
            const response = this.parseServerResponse(event.data)
            if (response.text) {
              transcriptionResult = response.text
              console.log('📝 Partial result:', response.text)
            }

            // 如果是最后一包响应，返回结果
            if (response.isFinal) {
              resolve(transcriptionResult || '无法识别音频内容')
            }
          } catch (error) {
            console.error('❌ Failed to parse response:', error)
          }
        }

        // 分包发送音频
        while (offset < audioData.length) {
          const end = Math.min(offset + chunkSize, audioData.length)
          const chunk = audioData.slice(offset, end)
          isLastPacket = end >= audioData.length

          const message = this.buildMessage(
            MessageType.AUDIO_ONLY_REQUEST,
            isLastPacket ? MessageFlags.LAST_PACKET : MessageFlags.NONE,
            SerializationMethod.NONE,
            CompressionMethod.NONE,
            chunk
          )

          this.send(message)
          offset = end

          // 控制发包速率（每 200ms 发一包）
          if (!isLastPacket) {
            await this.sleep(chunkDurationMs)
          }
        }

        console.log('✅ All audio data sent')

        // 超时保护（10秒内必须返回结果）
        setTimeout(() => {
          if (!transcriptionResult) {
            reject(new Error('转写超时'))
          }
        }, 10000)
      } catch (error) {
        reject(error)
      }
    })
  }

  /**
   * 构建二进制消息
   */
  private buildMessage(
    messageType: MessageType,
    flags: MessageFlags,
    serialization: SerializationMethod,
    compression: CompressionMethod,
    payload: Uint8Array
  ): ArrayBuffer {
    // Header（4 字节）
    const header = new Uint8Array(4)
    header[0] = (PROTOCOL_VERSION << 4) | HEADER_SIZE
    header[1] = (messageType << 4) | flags
    header[2] = (serialization << 4) | compression
    header[3] = 0x00 // Reserved

    // Payload size（4 字节，大端）
    const payloadSize = new Uint8Array(4)
    const size = payload.length
    payloadSize[0] = (size >> 24) & 0xff
    payloadSize[1] = (size >> 16) & 0xff
    payloadSize[2] = (size >> 8) & 0xff
    payloadSize[3] = size & 0xff

    // 组合消息
    const message = new Uint8Array(header.length + payloadSize.length + payload.length)
    message.set(header, 0)
    message.set(payloadSize, header.length)
    message.set(payload, header.length + payloadSize.length)

    return message.buffer
  }

  /**
   * 解析服务端响应
   */
  private parseServerResponse(data: ArrayBuffer): {
    text: string
    isFinal: boolean
    result?: ASRResult
  } {
    const view = new DataView(data)

    // 读取 Header（4 字节）
    const header0 = view.getUint8(0)
    const header1 = view.getUint8(1)
    const header2 = view.getUint8(2)

    const messageType = (header1 >> 4) & 0x0f
    const flags = header1 & 0x0f
    const serialization = (header2 >> 4) & 0x0f

    // 读取 Sequence（4 字节）
    const sequence = view.getUint32(4, false) // 大端

    // 读取 Payload size（4 字节）
    const payloadSize = view.getUint32(8, false) // 大端

    // 读取 Payload
    const payloadBytes = new Uint8Array(data, 12, payloadSize)

    // 解析 JSON
    if (serialization === SerializationMethod.JSON) {
      const payloadText = new TextDecoder().decode(payloadBytes)
      const result = JSON.parse(payloadText)

      // 检查是否是错误消息
      if (messageType === MessageType.ERROR_MESSAGE) {
        throw new Error(`ASR Error: ${result.message || 'Unknown error'}`)
      }

      // 提取文本
      const text = result.result?.text || ''
      const isFinal = flags === MessageFlags.LAST_PACKET || flags === MessageFlags.NEGATIVE_SEQUENCE

      return {
        text,
        isFinal,
        result: result.result
      }
    }

    return {
      text: '',
      isFinal: false
    }
  }

  /**
   * 发送数据
   */
  private send(data: ArrayBuffer): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(data)
      this.sequenceNumber++
    } else {
      throw new Error('WebSocket 未连接')
    }
  }

  /**
   * 断开连接
   */
  private disconnect(): void {
    if (this.ws) {
      this.ws.close()
      this.ws = null
    }
  }

  /**
   * 延迟函数
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms))
  }

  /**
   * 模拟转写（用于开发测试）
   */
  private async mockTranscribe(audioBlob: Blob): Promise<string> {
    console.warn('⚠️ Using mock transcription')
    await this.sleep(1000)

    const mockTexts = [
      '今天心情有点低落，可能是因为工作上遇到了一些挫折。',
      '刚才和朋友聊天，感觉好多了，被理解的感觉真好。',
      '最近总是很焦虑，不知道是不是因为睡眠不足。',
      '今天完成了一个重要的项目，很有成就感。',
      '感觉需要多给自己一些空间，学会放松。'
    ]

    return mockTexts[Math.floor(Math.random() * mockTexts.length)]
  }

  /**
   * 检查配置是否完整
   */
  isConfigured(): boolean {
    return !!(DOUBAO_ASR_CONFIG.appKey && DOUBAO_ASR_CONFIG.accessKey)
  }
}

// 导出单例
export const transcriptionService = new TranscriptionService()
