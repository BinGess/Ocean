/**
 * 环境变量管理
 */

/**
 * 豆包语音识别 API 配置
 */
export const DOUBAO_ASR_CONFIG = {
  apiKey: import.meta.env.VITE_DOUBAO_ASR_API_KEY || '',
  appId: import.meta.env.VITE_DOUBAO_ASR_APP_ID || '',
  // 根据豆包文档配置端点
  endpoint: 'wss://openspeech.bytedance.com/api/v1/asr'
}

/**
 * 豆包大模型 API 配置
 */
export const DOUBAO_LLM_CONFIG = {
  apiKey: import.meta.env.VITE_DOUBAO_LLM_API_KEY || '',
  endpoint: import.meta.env.VITE_DOUBAO_LLM_ENDPOINT || 'https://ark.cn-beijing.volces.com/api/v3',
  modelId: import.meta.env.VITE_DOUBAO_MODEL_ID || ''
}

/**
 * 应用配置
 */
export const APP_CONFIG = {
  name: 'MindFlow',
  version: '0.1.0',
  isDevelopment: import.meta.env.DEV,
  isProduction: import.meta.env.PROD
}

/**
 * 验证环境变量是否配置完整
 */
export function validateEnv(): {
  isValid: boolean
  missingKeys: string[]
} {
  const requiredKeys = [
    'VITE_DOUBAO_ASR_API_KEY',
    'VITE_DOUBAO_ASR_APP_ID',
    'VITE_DOUBAO_LLM_API_KEY',
    'VITE_DOUBAO_MODEL_ID'
  ]

  const missingKeys = requiredKeys.filter(key => !import.meta.env[key])

  return {
    isValid: missingKeys.length === 0,
    missingKeys
  }
}
