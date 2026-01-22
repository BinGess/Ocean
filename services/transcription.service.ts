/**
 * 语音转文本服务（豆包 ASR）
 *
 * 注意：由于无法访问豆包文档，这里提供的是通用的实现框架
 * 需要根据实际的豆包 ASR API 文档调整参数和实现细节
 */

import { DOUBAO_ASR_CONFIG } from '../config/env'

export interface TranscriptionOptions {
  language?: string
  enablePunctuation?: boolean
  enableNumberConversion?: boolean
}

export class TranscriptionService {
  private apiKey: string
  private appId: string
  private endpoint: string

  constructor() {
    this.apiKey = DOUBAO_ASR_CONFIG.apiKey
    this.appId = DOUBAO_ASR_CONFIG.appId
    this.endpoint = DOUBAO_ASR_CONFIG.endpoint
  }

  /**
   * 语音转文本（WebSocket 流式识别）
   *
   * 根据豆包文档，流式识别通常使用 WebSocket 协议
   */
  async transcribe(
    audioBlob: Blob,
    options?: TranscriptionOptions
  ): Promise<string> {
    // 方案 1: 豆包 WebSocket 流式识别（需要根据文档实现）
    // return this.transcribeWithWebSocket(audioBlob, options)

    // 方案 2: 如果豆包提供 HTTP API（需要根据文档实现）
    // return this.transcribeWithHTTP(audioBlob, options)

    // 临时方案 3: 使用浏览器内置的 Web Speech API（用于开发测试）
    return this.transcribeWithWebSpeech(audioBlob, options)
  }

  /**
   * 使用豆包 WebSocket 流式识别（需要根据实际文档实现）
   *
   * 典型的流程：
   * 1. 建立 WebSocket 连接
   * 2. 发送认证信息和配置参数
   * 3. 分片发送音频数据
   * 4. 接收识别结果
   * 5. 关闭连接
   */
  private async transcribeWithWebSocket(
    audioBlob: Blob,
    options?: TranscriptionOptions
  ): Promise<string> {
    return new Promise((resolve, reject) => {
      // TODO: 根据豆包文档实现 WebSocket 连接
      const ws = new WebSocket(this.endpoint)

      let transcription = ''

      ws.onopen = () => {
        console.log('🔌 WebSocket connected')

        // TODO: 发送认证和配置信息（根据豆包文档格式）
        const config = {
          app_id: this.appId,
          api_key: this.apiKey,
          language: options?.language || 'zh-CN',
          enable_punctuation: options?.enablePunctuation ?? true,
          enable_number_conversion: options?.enableNumberConversion ?? true
        }

        ws.send(JSON.stringify(config))

        // TODO: 分片发送音频数据
        this.sendAudioData(ws, audioBlob)
      }

      ws.onmessage = (event) => {
        try {
          const result = JSON.parse(event.data)

          // TODO: 根据豆包响应格式解析
          // 通常会有 result.text 或类似字段
          if (result.text) {
            transcription += result.text
          }

          // 如果收到结束标志
          if (result.is_final) {
            ws.close()
            resolve(transcription)
          }
        } catch (error) {
          console.error('Failed to parse transcription result:', error)
        }
      }

      ws.onerror = (error) => {
        console.error('WebSocket error:', error)
        reject(new Error('语音识别失败'))
      }

      ws.onclose = () => {
        console.log('🔌 WebSocket closed')
        if (transcription) {
          resolve(transcription)
        }
      }
    })
  }

  /**
   * 分片发送音频数据
   */
  private async sendAudioData(ws: WebSocket, audioBlob: Blob): Promise<void> {
    const chunkSize = 1024 * 8 // 8KB per chunk
    const arrayBuffer = await audioBlob.arrayBuffer()
    const uint8Array = new Uint8Array(arrayBuffer)

    for (let i = 0; i < uint8Array.length; i += chunkSize) {
      const chunk = uint8Array.slice(i, i + chunkSize)

      if (ws.readyState === WebSocket.OPEN) {
        ws.send(chunk)
        // 可选：添加延迟以模拟实时音频流
        await new Promise(resolve => setTimeout(resolve, 100))
      }
    }

    // 发送结束标志
    ws.send(JSON.stringify({ type: 'finish' }))
  }

  /**
   * 使用浏览器内置 Web Speech API（临时开发方案）
   * 注意：这个 API 在生产环境可能不稳定，仅用于开发测试
   */
  private async transcribeWithWebSpeech(
    audioBlob: Blob,
    options?: TranscriptionOptions
  ): Promise<string> {
    // Web Speech API 需要实时音频流，无法直接处理 Blob
    // 这里返回一个模拟的结果用于开发测试

    console.warn('⚠️ Using mock transcription (Web Speech API not available for Blob)')

    // 模拟转写延迟
    await new Promise(resolve => setTimeout(resolve, 1000))

    // 返回模拟文本（实际应该调用豆包 API）
    return '这是一段模拟的语音转文本结果。请配置豆包 API 密钥以使用真实的语音识别功能。'
  }

  /**
   * 验证 API 配置是否完整
   */
  isConfigured(): boolean {
    return !!(this.apiKey && this.appId)
  }
}

// 导出单例实例
export const transcriptionService = new TranscriptionService()
