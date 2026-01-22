/**
 * AI 分析服务（使用豆包大模型）
 * 负责：NVC 分析、日记旁注、周洞察生成
 */

import { doubaoClient } from './api/client'
import { FeelingItem, MicroExperiment } from '../models'

export class AIAnalysisService {
  /**
   * NVC 分析（碎片记录）
   * 根据转写内容，提取观察、感受、需要、请求
   */
  async analyzeWithNVC(transcription: string): Promise<{
    observation: string
    feelings: FeelingItem[]
    needs: string[]
    request?: string
  }> {
    const systemPrompt = `你是一个情绪觉察助手，专注于帮助用户理解自己的情绪和需要。
请基于用户的语音转文本内容，按照 NVC（非暴力沟通）框架进行分析。

输出格式要求（JSON）：
{
  "observation": "客观描述发生了什么，避免评判词",
  "feelings": [
    { "emotion": "情绪ID（如 anxious, happy, frustrated）", "intensity": 1-5 }
  ],
  "needs": ["need_id1", "need_id2"],
  "request": "可选的行动建议"
}

重要原则：
1. 观察必须客观，像摄像头一样描述事实
2. 情绪词从常见情绪中选择：happy, sad, angry, anxious, calm, excited, worried, frustrated, lonely, grateful, fear, tired, confused, annoyed, peaceful
3. 需要从常见需要中选择：understanding, autonomy, connection, safety, rest, meaning, control, acceptance, belonging, trust, freedom, growth, peace
4. 文案使用"可能/也许"，避免诊断性语言
5. 如果用户没有明确表达请求，request 可以为空`

    const userPrompt = `用户说的话：\n${transcription}\n\n请分析并返回 JSON 格式的结果。`

    try {
      const response = await doubaoClient.prompt(userPrompt, systemPrompt)

      // 尝试解析 JSON
      const result = this.parseJSONResponse(response)

      return {
        observation: result.observation || '未能提取观察内容',
        feelings: this.normalizeFeelings(result.feelings || []),
        needs: Array.isArray(result.needs) ? result.needs : [],
        request: result.request
      }
    } catch (error) {
      console.error('❌ NVC analysis failed:', error)
      throw new Error('NVC 分析失败，请稍后重试')
    }
  }

  /**
   * 日记旁注生成
   * 提取关键片段、情绪峰值、建议的需要、微实验
   */
  async generateJournalAnnotation(
    originalText: string,
    referencedFragments?: string[]
  ): Promise<{
    keyFragments: Array<{ text: string; category: 'event' | 'emotion' | 'insight' }>
    emotionPeaks: Array<{ text: string; emotion: string; intensity: number }>
    suggestedNeeds: string[]
    microExperiment?: MicroExperiment
    reflectionQuestions?: string[]
  }> {
    const systemPrompt = `你是一个情绪觉察助手，帮助用户整理日记内容。

请基于用户的日记原文，生成旁注信息（不要改写原文！）：

输出格式（JSON）：
{
  "keyFragments": [
    { "text": "原文片段引用", "category": "event|emotion|insight" }
  ],
  "emotionPeaks": [
    { "text": "情绪峰值片段", "emotion": "情绪ID", "intensity": 1-5 }
  ],
  "suggestedNeeds": ["need_id1", "need_id2"],
  "microExperiment": {
    "trigger": "触发信号",
    "action30s": "30秒可执行的小动作",
    "needFulfilled": "满足的需要"
  },
  "reflectionQuestions": ["问题1", "问题2"]
}

重要原则：
1. 所有 text 字段必须是原文引用（不超过50字）
2. 不要编造内容，只提取和标注
3. 微实验必须非常具体、可执行、30秒内完成
4. 反思问题最多2个，用谨慎措辞`

    const userPrompt = `日记原文：\n${originalText}\n\n${
      referencedFragments && referencedFragments.length > 0
        ? `\n引用的碎片：\n${referencedFragments.join('\n---\n')}\n`
        : ''
    }\n请生成旁注（JSON格式）。`

    try {
      const response = await doubaoClient.prompt(userPrompt, systemPrompt)
      const result = this.parseJSONResponse(response)

      return {
        keyFragments: result.keyFragments || [],
        emotionPeaks: result.emotionPeaks || [],
        suggestedNeeds: result.suggestedNeeds || [],
        microExperiment: result.microExperiment,
        reflectionQuestions: result.reflectionQuestions
      }
    } catch (error) {
      console.error('❌ Journal annotation failed:', error)
      throw new Error('日记旁注生成失败')
    }
  }

  /**
   * 生成日记摘要（1-2句话）
   */
  async generateSummary(originalText: string): Promise<string> {
    const systemPrompt = `请用 1-2 句话（不超过50字）概括这篇日记的核心内容。`

    try {
      return await doubaoClient.prompt(originalText, systemPrompt)
    } catch (error) {
      console.error('❌ Summary generation failed:', error)
      return originalText.slice(0, 50) + '...'
    }
  }

  /**
   * 生成周洞察
   */
  async generateWeeklyInsight(recordsData: {
    transcriptions: string[]
    moodsSummary: string
    needsSummary: string
  }): Promise<{
    emotionOverview: string
    triggerScenarios: Array<{
      scenario: string
      commonFeelings: string[]
      commonNeeds: string[]
      evidenceQuote: string
    }>
    patternHypothesis: {
      statement: string
      confidence: 'low' | 'medium' | 'high'
    }
    microExperiment: MicroExperiment
  }> {
    const systemPrompt = `你是情绪觉察助手，基于用户本周的记录生成洞察信。

输出格式（JSON）：
{
  "emotionOverview": "本周情绪概览（2-3句话）",
  "triggerScenarios": [
    {
      "scenario": "高频情境描述",
      "commonFeelings": ["情绪ID"],
      "commonNeeds": ["需要ID"],
      "evidenceQuote": "原文短引用"
    }
  ],
  "patternHypothesis": {
    "statement": "你可能在【情境】里经常触发【感受】，背后常出现【需要】的需要",
    "confidence": "low|medium|high"
  },
  "microExperiment": {
    "trigger": "什么时候会开始进入旧模式",
    "action30s": "30秒小动作",
    "needFulfilled": "满足的需要"
  }
}

原则：
1. 使用"可能/也许"，不诊断
2. 所有引用必须来自原文
3. 样本不足时降低 confidence
4. 微实验必须具体可执行`

    const userPrompt = `本周记录数据：
情绪统计：${recordsData.moodsSummary}
需要统计：${recordsData.needsSummary}

部分原文片段：
${recordsData.transcriptions.slice(0, 10).join('\n---\n')}

请生成周洞察（JSON格式）。`

    try {
      const response = await doubaoClient.prompt(userPrompt, systemPrompt)
      return this.parseJSONResponse(response)
    } catch (error) {
      console.error('❌ Weekly insight generation failed:', error)
      throw new Error('周洞察生成失败')
    }
  }

  /**
   * 解析 JSON 响应（处理可能的格式问题）
   */
  private parseJSONResponse(response: string): any {
    try {
      // 尝试直接解析
      return JSON.parse(response)
    } catch {
      // 如果失败，尝试提取 JSON 代码块
      const jsonMatch = response.match(/```json\n([\s\S]*?)\n```/)
      if (jsonMatch) {
        return JSON.parse(jsonMatch[1])
      }

      // 尝试提取 { ... } 部分
      const objectMatch = response.match(/\{[\s\S]*\}/)
      if (objectMatch) {
        return JSON.parse(objectMatch[0])
      }

      throw new Error('无法解析 AI 响应')
    }
  }

  /**
   * 标准化感受数据
   */
  private normalizeFeelings(feelings: any[]): FeelingItem[] {
    return feelings.map(f => ({
      emotion: f.emotion || f.id || 'uncertain',
      intensity: Math.min(Math.max(f.intensity || 3, 1), 5) as 1 | 2 | 3 | 4 | 5
    }))
  }
}

// 导出单例实例
export const aiAnalysisService = new AIAnalysisService()
