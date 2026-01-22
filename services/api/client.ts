/**
 * API 客户端封装（豆包 LLM API）
 */

import { DOUBAO_LLM_CONFIG } from '../../config/env'

export interface DoubaoMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

export interface DoubaoRequest {
  model: string
  messages: DoubaoMessage[]
  temperature?: number
  top_p?: number
  max_tokens?: number
  stream?: boolean
}

export interface DoubaoResponse {
  id: string
  choices: Array<{
    index: number
    message: {
      role: string
      content: string
    }
    finish_reason: string
  }>
  usage: {
    prompt_tokens: number
    completion_tokens: number
    total_tokens: number
  }
}

/**
 * 豆包 API 客户端
 */
export class DoubaoClient {
  private apiKey: string
  private endpoint: string
  private modelId: string

  constructor() {
    this.apiKey = DOUBAO_LLM_CONFIG.apiKey
    this.endpoint = DOUBAO_LLM_CONFIG.endpoint
    this.modelId = DOUBAO_LLM_CONFIG.modelId

    if (!this.apiKey || !this.modelId) {
      console.warn('⚠️ Doubao API credentials not configured')
    }
  }

  /**
   * 发送聊天请求
   */
  async chat(
    messages: DoubaoMessage[],
    options?: {
      temperature?: number
      maxTokens?: number
    }
  ): Promise<string> {
    const requestBody: DoubaoRequest = {
      model: this.modelId,
      messages,
      temperature: options?.temperature ?? 0.7,
      max_tokens: options?.maxTokens ?? 2000,
      stream: false
    }

    try {
      const response = await fetch(`${this.endpoint}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`
        },
        body: JSON.stringify(requestBody)
      })

      if (!response.ok) {
        const errorText = await response.text()
        throw new Error(`Doubao API error: ${response.status} - ${errorText}`)
      }

      const data: DoubaoResponse = await response.json()

      if (!data.choices || data.choices.length === 0) {
        throw new Error('No response from Doubao API')
      }

      return data.choices[0].message.content
    } catch (error) {
      console.error('❌ Doubao API error:', error)
      throw error
    }
  }

  /**
   * 发送单个 prompt（便捷方法）
   */
  async prompt(
    userPrompt: string,
    systemPrompt?: string
  ): Promise<string> {
    const messages: DoubaoMessage[] = []

    if (systemPrompt) {
      messages.push({
        role: 'system',
        content: systemPrompt
      })
    }

    messages.push({
      role: 'user',
      content: userPrompt
    })

    return this.chat(messages)
  }
}

// 导出单例实例
export const doubaoClient = new DoubaoClient()
