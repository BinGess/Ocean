import 'package:flutter/material.dart';

/// 应用本地化类
/// 提供中英文翻译支持
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('zh'),
    Locale('en'),
  ];

  // 翻译映射表
  static final Map<String, Map<String, String>> _localizedValues = {
    'zh': {
      'appTitle': 'MindFlow',
      'navRecords': '记录',
      'navHome': '瞬记',
      'navInsights': '洞察',
      'navMe': '我的',
      'profileNickname': 'MindFlow 用户',
      'profileSubtitle': '慢慢记录，也慢慢理解自己',
      'myWeeklyUnavailable': '记录更多内容后，这里会出现本周概览',
      'editProfile': '编辑个人信息',
      'profileAvatar': '头像',
      'profileNicknameLabel': '昵称',
      'profileSignature': '签名',
      'profileAvatarDefault': '我',
      'save': '保存',
      'manageSubscription': '管理订阅',
      'moreSettings': '更多设置',
      'settings': '设置',
      'securityAndPrivacy': '安全与隐私',
      'appLock': '应用锁',
      'appLockSubtitle': '使用密码或生物识别保护隐私',
      'aiServiceAuth': 'AI服务授权',
      'aiServiceAuthSubtitle': '允许使用火山引擎豆包大模型分析日记',
      'dataManagement': '数据管理',
      'export': '导出',
      'exportSubtitle': '导出所有记录或洞察信息',
      'iCloudSync': 'iCloud 云同步',
      'iCloudSyncSubtitle': '将记录、每日心情、日总结和每周总结保存到 iCloud',
      'iCloudSyncUnavailable': '当前设备未开启 iCloud Drive，暂时无法使用',
      'iCloudSyncEnabled': '已开启 iCloud 云同步',
      'iCloudSyncDisabled': '已关闭 iCloud 云同步',
      'iCloudSyncFailed': 'iCloud 云同步设置失败，请稍后重试',
      'iCloudBackupStatusTitle': '云端备份状态',
      'iCloudBackupChecking': '正在检查云端备份...',
      'iCloudBackupNotFound': '暂未发现云端备份，开启后会自动创建',
      'iCloudBackupLastSynced': '上次同步',
      'iCloudBackupContent': '备份内容',
      'iCloudBackupRecords': '条记录',
      'iCloudBackupWeeklyInsights': '个周洞察',
      'iCloudBackupReports': '份报告',
      'iCloudBackupFile': '备份文件',
      'iCloudBackupTimeUnknown': '时间未知',
      'other': '其他',
      'about': '关于',
      'aboutSubtitle': '应用信息与隐私协议',
      'language': '语言',
      'languageSubtitle': '切换应用显示语言',
      'languageChinese': '中文',
      'languageEnglish': 'English',
      'languageSystem': '跟随系统',
      'cancel': '取消',
      'confirm': '确定',
      'close': '关闭',
      'disableAIService': '关闭AI服务',
      'disableAIServiceConfirm': '关闭后将无法使用NVC情绪分析和周洞察功能，是否继续？',
      'dailyRecords': '每日记录',
      'today': '今天',
      'yesterday': '昨天',
      'monday': '周一',
      'tuesday': '周二',
      'wednesday': '周三',
      'thursday': '周四',
      'friday': '周五',
      'saturday': '周六',
      'sunday': '周日',
      'loadFailed': '加载失败',
      'retry': '重试',
      'noRecords': '暂无记录',
      'recordDeleted': '记录已删除',
      'enableSmartInsights': '开启智能洞察',
      'enableSmartInsightsDesc': '授权AI服务后，将为您分析本周情绪记录\n生成专属的情绪洞察报告',
      'enableNow': '立即开启',
      'learnMore': '了解更多',
      'generatingInsight': '正在生成洞察...',
      'noEnoughContent': '本周没有足够的内容生成洞察',
      'autoGenerateAfterMore': '记录更多内容后将自动生成',
      'regenerate': '重新生成',
      'refreshFailed': '刷新失败，请稍后重试',
      'aiAuthExpired': 'AI授权已失效，请在设置中重新开启',
      'aiNeedsAuthSnackbar': 'AI功能需要授权才能使用，您可在设置中开启',
      'goToSettings': '去设置',
      'viewHistoryReports': '查看历史报告',
      'emotionOverview': '情绪概览',
      'highFrequencySituations': '高频情境',
      'potentialNeeds': '潜在需求',
      'actionSuggestions': '行动建议',
      'justNow': '刚刚更新',
      'holdToRecord': '长按说话',
      'recordButtonTapToRecord': '点击录音',
      'recordButtonHoldSemantics': '长按开始录音',
      'recordButtonHoldHint': '双击并长按开始录音',
      'recordButtonTapSemantics': '点击开始录音',
      'recordButtonTapHint': '双击开始或停止录音',
      'recording': '录音中...',
      'releaseToSend': '松开发送',
      'recordingTooShort': '录音时间太短',
      'microphonePermissionDenied': '需要麦克风权限',
      'saveFailedRetry': '保存失败，请重试',
      'emotionInputTitle': '描述下你此刻的心情？',
      'emotionInputHint': '尽情书写，让我帮你分析此刻的心情',
      'emotionInputSave': '仅文字保存',
      'emotionInputAnalyze': 'NVC分析',
      'emotionGrantPermissionFirst': '请先授予录音权限',
      'emotionEnterContentBeforeSave': '请输入内容后再保存',
      'emotionEnterContentBeforeAnalyze': '请输入内容后再分析',
      'emotionEmptyInputCannotContinue': '输入内容为空，无法继续分析',
      'emotionEmptyInputCannotSave': '输入内容为空，无法保存',
      'emotionFinishingRecording': '正在结束录音...',
      'emotionTranscriptionManualFallback': '转写失败，请手动补充内容后再试',
      'homeGreetingMorning': '早上好',
      'homeGreetingAfternoon': '下午好',
      'homeGreetingEvening': '晚上好',
      'homeContentTooShortRetry': '内容太短，请重试',
      'homeSavingRecord': '正在保存记录...',
      'homeSaveCancelled': '已取消保存',
      'homeRecordSaved': '记录已保存',
      'homeTranscriptionPending': '转写未完成，请稍后...',
      'homeNoTranscriptionFallback': '暂无转写文本，已自动转为仅记录',
      'homeRecordPrompt': '记录下此刻的情绪',
      'homeStartVoiceRecord': '开始语音记录',
      'homeOpenVoiceInputHint': '打开语音录制输入',
      'moodPickerTitle': '今天心情如何？',
      'moodPickerSubtitle': '选择一个表情来记录今天的心情',
      'moodHappy': '开心',
      'moodCalm': '平静',
      'moodLoved': '幸福',
      'moodSad': '低落',
      'moodAnnoyed': '烦躁',
      'moodAnxious': '焦虑',
      'moodTired': '疲惫',
      'moodConfused': '困惑',
      'selectLanguage': '选择语言',
      // Export screen
      'exportSelectContent': '选择导出内容',
      'exportSelectFormat': '选择导出格式',
      'exportDateRange': '日期范围',
      'exportRecords': '记录',
      'exportInsights': '洞察报告',
      'exportFormatMarkdownDesc': '适合阅读',
      'exportFormatCsvDesc': '表格格式',
      'exportFormatJsonDesc': '数据备份',
      'exportRange7Days': '最近7天',
      'exportRange30Days': '最近30天',
      'exportRange3Months': '近3个月',
      'exportRangeAll': '全部',
      'exportCustomRange': '自定义范围',
      'exportPreview': '导出预览',
      'exportPreviewContent': '内容',
      'exportPreviewFormat': '格式',
      'exportPreviewRange': '范围',
      'exportPreviewFile': '文件',
      'exportNoSelection': '未选择任何内容',
      'exportButton': '导出文件',
      'exportSuccess': '导出成功',
      'exportNoData': '所选范围内没有可导出的数据',
      'exportFailed': '导出失败，请稍后再试',
      'exportShareText': '瞬记 · 数据导出',
      'exportContentPreview': '内容预览',
      'exportLoadingData': '正在加载数据...',
      'exportEmptyTitle': '暂无可导出的数据',
      'exportEmptySubtitle': '记录一些内容后，就可以在这里导出了',
      'exportActionShare': '分享文件',
      'exportActionDone': '完成',
      // Pro 订阅相关
      'pro': 'Pro',
      'proMembership': 'Pro 会员',
      'proPrice': '¥1/月',
      'proPurchaseTitle': '升级为 Pro 会员',
      'proPurchaseSubtitle': '解锁全部高级功能，让记录更完整',
      'proFeatureExport': '导出所有记录',
      'proFeatureExportDesc': '将你的情绪记录导出为 JSON 文件，随时备份和迁移数据',
      'proFeatureICloud': 'iCloud 云同步',
      'proFeatureICloudDesc': '自动同步到 iCloud，多设备无缝切换，数据永不丢失',
      'proSubscribeButton': '立即订阅 — ¥1/月',
      'proRestorePurchase': '恢复购买',
      'proAlreadySubscribed': '你已经是 Pro 会员',
      'proSubscribeSuccess': '订阅成功，欢迎成为 Pro 会员！',
      'proSubscribeFailed': '订阅失败，请稍后重试',
      'proProductNotAvailable': '价格获取失败，请检查网络后重试',
      'proPriceRetry': '重新获取价格',
      'proRequired': '此功能需要 Pro 会员',
      'proRestoreNone': '未找到可恢复的购买记录',
      'proSubscribeNow': '立即订阅',
      'proPerMonth': '月',
      'proSubscriptionNote':
          '订阅将通过您的 Apple ID 账户确认购买。\n订阅会自动续订，除非您在当前订阅期结束前至少24小时关闭自动续订。\n您可以在 App Store 账户设置中管理和取消订阅。',
      'debugMode': 'DEBUG 模式',
      'debugModeSubtitle': '开启后无需订阅即可使用导出与 iCloud（仅供内部测试）',
    },
    'en': {
      'appTitle': 'MindFlow',
      'navRecords': 'Records',
      'navHome': 'Record',
      'navInsights': 'Insights',
      'navMe': 'Me',
      'profileNickname': 'MindFlow User',
      'profileSubtitle': 'Keep noticing, one entry at a time',
      'myWeeklyUnavailable':
          'Your weekly overview will appear here after more records',
      'editProfile': 'Edit profile',
      'profileAvatar': 'Avatar',
      'profileNicknameLabel': 'Nickname',
      'profileSignature': 'Signature',
      'profileAvatarDefault': 'M',
      'save': 'Save',
      'manageSubscription': 'Manage Subscription',
      'moreSettings': 'More Settings',
      'settings': 'Settings',
      'securityAndPrivacy': 'Security & Privacy',
      'appLock': 'App Lock',
      'appLockSubtitle': 'Protect privacy with password or biometrics',
      'aiServiceAuth': 'AI Service Authorization',
      'aiServiceAuthSubtitle': 'Allow using AI to analyze your journal',
      'dataManagement': 'Data Management',
      'export': 'Export',
      'exportSubtitle': 'Export all records or insights',
      'iCloudSync': 'iCloud Sync',
      'iCloudSyncSubtitle':
          'Save records, daily moods, daily summaries and weekly insights to iCloud',
      'iCloudSyncUnavailable':
          'iCloud Drive is unavailable on this device right now',
      'iCloudSyncEnabled': 'iCloud sync enabled',
      'iCloudSyncDisabled': 'iCloud sync disabled',
      'iCloudSyncFailed': 'Failed to update iCloud sync settings',
      'iCloudBackupStatusTitle': 'Cloud backup status',
      'iCloudBackupChecking': 'Checking cloud backup...',
      'iCloudBackupNotFound':
          'No cloud backup found yet. One will be created after sync is enabled.',
      'iCloudBackupLastSynced': 'Last synced',
      'iCloudBackupContent': 'Backup content',
      'iCloudBackupRecords': 'records',
      'iCloudBackupWeeklyInsights': 'weekly insights',
      'iCloudBackupReports': 'reports',
      'iCloudBackupFile': 'Backup file',
      'iCloudBackupTimeUnknown': 'Unknown time',
      'other': 'Other',
      'about': 'About',
      'aboutSubtitle': 'App info and privacy policy',
      'language': 'Language',
      'languageSubtitle': 'Switch app display language',
      'languageChinese': 'Chinese',
      'languageEnglish': 'English',
      'languageSystem': 'System Default',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'close': 'Close',
      'disableAIService': 'Disable AI Service',
      'disableAIServiceConfirm':
          'After disabling, NVC emotion analysis and weekly insights will be unavailable. Continue?',
      'dailyRecords': 'Daily Records',
      'today': 'Today',
      'yesterday': 'Yesterday',
      'monday': 'Mon',
      'tuesday': 'Tue',
      'wednesday': 'Wed',
      'thursday': 'Thu',
      'friday': 'Fri',
      'saturday': 'Sat',
      'sunday': 'Sun',
      'loadFailed': 'Load failed',
      'retry': 'Retry',
      'noRecords': 'No records yet',
      'recordDeleted': 'Record deleted',
      'enableSmartInsights': 'Enable Smart Insights',
      'enableSmartInsightsDesc':
          'After authorizing AI service, we will analyze\nyour weekly emotion records and generate\npersonalized insight reports',
      'enableNow': 'Enable Now',
      'learnMore': 'Learn More',
      'generatingInsight': 'Generating insights...',
      'noEnoughContent': 'Not enough content to generate insights this week',
      'autoGenerateAfterMore': 'Will auto-generate after more records',
      'regenerate': 'Regenerate',
      'refreshFailed': 'Refresh failed, please try again later',
      'aiAuthExpired': 'AI authorization expired, please re-enable in settings',
      'aiNeedsAuthSnackbar':
          'AI features require authorization. Enable in settings',
      'goToSettings': 'Settings',
      'viewHistoryReports': 'View History',
      'emotionOverview': 'Emotion Overview',
      'highFrequencySituations': 'Frequent Situations',
      'potentialNeeds': 'Potential Needs',
      'actionSuggestions': 'Suggestions',
      'justNow': 'Just now',
      'holdToRecord': 'Hold to speak',
      'recordButtonTapToRecord': 'Tap to record',
      'recordButtonHoldSemantics': 'Hold to speak',
      'recordButtonHoldHint': 'Double tap and hold to start recording',
      'recordButtonTapSemantics': 'Tap to record',
      'recordButtonTapHint': 'Double tap to start or stop recording',
      'recording': 'Recording...',
      'releaseToSend': 'Release to send',
      'recordingTooShort': 'Recording too short',
      'microphonePermissionDenied': 'Microphone permission required',
      'saveFailedRetry': 'Save failed, please try again',
      'emotionInputTitle': 'What are you feeling right now?',
      'emotionInputHint':
          'Write freely and let me help you understand this moment',
      'emotionInputSave': 'Save Text Only',
      'emotionInputAnalyze': 'NVC Analyze',
      'emotionGrantPermissionFirst': 'Please grant microphone permission first',
      'emotionEnterContentBeforeSave': 'Enter some text before saving',
      'emotionEnterContentBeforeAnalyze': 'Enter some text before analyzing',
      'emotionEmptyInputCannotContinue': 'Input is empty, unable to continue',
      'emotionEmptyInputCannotSave': 'Input is empty, unable to save',
      'emotionFinishingRecording': 'Finishing recording...',
      'emotionTranscriptionManualFallback':
          'Transcription failed. Add your text manually and try again',
      'homeGreetingMorning': 'Good morning',
      'homeGreetingAfternoon': 'Good afternoon',
      'homeGreetingEvening': 'Good evening',
      'homeContentTooShortRetry': 'Content is too short, please try again',
      'homeSavingRecord': 'Saving your note...',
      'homeSaveCancelled': 'Save canceled',
      'homeRecordSaved': 'Saved',
      'homeTranscriptionPending': 'Transcription is still in progress...',
      'homeNoTranscriptionFallback':
          'No transcript yet. Switched to save-only mode automatically',
      'homeRecordPrompt': 'Capture how you feel right now',
      'homeStartVoiceRecord': 'Start voice note',
      'homeOpenVoiceInputHint': 'Open the voice input composer',
      'moodPickerTitle': 'How are you feeling today?',
      'moodPickerSubtitle': 'Choose a mood to capture today',
      'moodHappy': 'Happy',
      'moodCalm': 'Calm',
      'moodLoved': 'Loved',
      'moodSad': 'Low',
      'moodAnnoyed': 'Annoyed',
      'moodAnxious': 'Anxious',
      'moodTired': 'Tired',
      'moodConfused': 'Confused',
      'selectLanguage': 'Select Language',
      // Export screen
      'exportSelectContent': 'Select Content',
      'exportSelectFormat': 'Export Format',
      'exportDateRange': 'Date Range',
      'exportRecords': 'Records',
      'exportInsights': 'Insight Reports',
      'exportFormatMarkdownDesc': 'Readable',
      'exportFormatCsvDesc': 'Spreadsheet',
      'exportFormatJsonDesc': 'Data backup',
      'exportRange7Days': '7 days',
      'exportRange30Days': '30 days',
      'exportRange3Months': '3 months',
      'exportRangeAll': 'All',
      'exportCustomRange': 'Custom range',
      'exportPreview': 'Export Preview',
      'exportPreviewContent': 'Content',
      'exportPreviewFormat': 'Format',
      'exportPreviewRange': 'Range',
      'exportPreviewFile': 'File',
      'exportNoSelection': 'Nothing selected',
      'exportButton': 'Export',
      'exportSuccess': 'Export Successful',
      'exportNoData': 'No data in the selected range',
      'exportFailed': 'Export failed, please try again',
      'exportShareText': 'MindFlow · Data Export',
      'exportContentPreview': 'Content Preview',
      'exportLoadingData': 'Loading data...',
      'exportEmptyTitle': 'No data to export',
      'exportEmptySubtitle': 'Start recording and your data will appear here',
      'exportActionShare': 'Share',
      'exportActionDone': 'Done',
      // Pro subscription
      'pro': 'Pro',
      'proMembership': 'Pro Membership',
      'proPrice': '¥1/mo',
      'proPurchaseTitle': 'Upgrade to Pro',
      'proPurchaseSubtitle':
          'Unlock all premium features for a complete experience',
      'proFeatureExport': 'Export All Records',
      'proFeatureExportDesc':
          'Export your emotion records as JSON files for backup and migration',
      'proFeatureICloud': 'iCloud Sync',
      'proFeatureICloudDesc':
          'Auto-sync to iCloud across devices, never lose your data',
      'proSubscribeButton': 'Subscribe — ¥1/mo',
      'proRestorePurchase': 'Restore Purchase',
      'proAlreadySubscribed': 'You are already a Pro member',
      'proSubscribeSuccess': 'Subscribed successfully! Welcome to Pro!',
      'proSubscribeFailed': 'Subscription failed, please try again later',
      'proProductNotAvailable':
          'Failed to load price. Please check your connection and try again.',
      'proPriceRetry': 'Retry',
      'proRequired': 'This feature requires Pro membership',
      'proRestoreNone': 'No purchase to restore',
      'proSubscribeNow': 'Subscribe Now',
      'proPerMonth': 'mo',
      'proSubscriptionNote':
          'Payment will be charged to your Apple ID account upon confirmation.\nSubscription automatically renews unless cancelled at least 24 hours before the end of the current period.\nYou can manage and cancel subscriptions in your App Store account settings.',
      'debugMode': 'DEBUG mode',
      'debugModeSubtitle':
          'When on, Export and iCloud work without subscription (internal testing only)',
    },
  };

  String _translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['zh']![key] ??
        key;
  }

  // Getters for all translations
  String get appTitle => _translate('appTitle');
  String get navRecords => _translate('navRecords');
  String get navHome => _translate('navHome');
  String get navInsights => _translate('navInsights');
  String get navMe => _translate('navMe');
  String get profileNickname => _translate('profileNickname');
  String get profileSubtitle => _translate('profileSubtitle');
  String get myWeeklyUnavailable => _translate('myWeeklyUnavailable');
  String get editProfile => _translate('editProfile');
  String get profileAvatar => _translate('profileAvatar');
  String get profileNicknameLabel => _translate('profileNicknameLabel');
  String get profileSignature => _translate('profileSignature');
  String get profileAvatarDefault => _translate('profileAvatarDefault');
  String get save => _translate('save');
  String get manageSubscription => _translate('manageSubscription');
  String get moreSettings => _translate('moreSettings');
  String get settings => _translate('settings');
  String get securityAndPrivacy => _translate('securityAndPrivacy');
  String get appLock => _translate('appLock');
  String get appLockSubtitle => _translate('appLockSubtitle');
  String get aiServiceAuth => _translate('aiServiceAuth');
  String get aiServiceAuthSubtitle => _translate('aiServiceAuthSubtitle');
  String get dataManagement => _translate('dataManagement');
  String get export => _translate('export');
  String get exportSubtitle => _translate('exportSubtitle');
  String get iCloudSync => _translate('iCloudSync');
  String get iCloudSyncSubtitle => _translate('iCloudSyncSubtitle');
  String get iCloudSyncUnavailable => _translate('iCloudSyncUnavailable');
  String get iCloudSyncEnabled => _translate('iCloudSyncEnabled');
  String get iCloudSyncDisabled => _translate('iCloudSyncDisabled');
  String get iCloudSyncFailed => _translate('iCloudSyncFailed');
  String get iCloudBackupStatusTitle => _translate('iCloudBackupStatusTitle');
  String get iCloudBackupChecking => _translate('iCloudBackupChecking');
  String get iCloudBackupNotFound => _translate('iCloudBackupNotFound');
  String get iCloudBackupLastSynced => _translate('iCloudBackupLastSynced');
  String get iCloudBackupContent => _translate('iCloudBackupContent');
  String get iCloudBackupRecords => _translate('iCloudBackupRecords');
  String get iCloudBackupWeeklyInsights =>
      _translate('iCloudBackupWeeklyInsights');
  String get iCloudBackupReports => _translate('iCloudBackupReports');
  String get iCloudBackupFile => _translate('iCloudBackupFile');
  String get iCloudBackupTimeUnknown => _translate('iCloudBackupTimeUnknown');
  String get other => _translate('other');
  String get showOnboardingAlways => _translate('showOnboardingAlways');
  String get showOnboardingAlwaysSubtitle =>
      _translate('showOnboardingAlwaysSubtitle');
  String get about => _translate('about');
  String get aboutSubtitle => _translate('aboutSubtitle');
  String get language => _translate('language');
  String get languageSubtitle => _translate('languageSubtitle');
  String get languageChinese => _translate('languageChinese');
  String get languageEnglish => _translate('languageEnglish');
  String get languageSystem => _translate('languageSystem');
  String get cancel => _translate('cancel');
  String get confirm => _translate('confirm');
  String get close => _translate('close');
  String get disableAIService => _translate('disableAIService');
  String get disableAIServiceConfirm => _translate('disableAIServiceConfirm');
  String get dailyRecords => _translate('dailyRecords');
  String get today => _translate('today');
  String get yesterday => _translate('yesterday');
  String get monday => _translate('monday');
  String get tuesday => _translate('tuesday');
  String get wednesday => _translate('wednesday');
  String get thursday => _translate('thursday');
  String get friday => _translate('friday');
  String get saturday => _translate('saturday');
  String get sunday => _translate('sunday');
  String get loadFailed => _translate('loadFailed');
  String get retry => _translate('retry');
  String get noRecords => _translate('noRecords');
  String get recordDeleted => _translate('recordDeleted');
  String get enableSmartInsights => _translate('enableSmartInsights');
  String get enableSmartInsightsDesc => _translate('enableSmartInsightsDesc');
  String get enableNow => _translate('enableNow');
  String get learnMore => _translate('learnMore');
  String get generatingInsight => _translate('generatingInsight');
  String get noEnoughContent => _translate('noEnoughContent');
  String get autoGenerateAfterMore => _translate('autoGenerateAfterMore');
  String get regenerate => _translate('regenerate');
  String get refreshFailed => _translate('refreshFailed');
  String get aiAuthExpired => _translate('aiAuthExpired');
  String get aiNeedsAuthSnackbar => _translate('aiNeedsAuthSnackbar');
  String get goToSettings => _translate('goToSettings');
  String get viewHistoryReports => _translate('viewHistoryReports');
  String get emotionOverview => _translate('emotionOverview');
  String get highFrequencySituations => _translate('highFrequencySituations');
  String get potentialNeeds => _translate('potentialNeeds');
  String get actionSuggestions => _translate('actionSuggestions');
  String get justNow => _translate('justNow');
  String get holdToRecord => _translate('holdToRecord');
  String get recordButtonTapToRecord => _translate('recordButtonTapToRecord');
  String get recordButtonHoldSemantics =>
      _translate('recordButtonHoldSemantics');
  String get recordButtonHoldHint => _translate('recordButtonHoldHint');
  String get recordButtonTapSemantics => _translate('recordButtonTapSemantics');
  String get recordButtonTapHint => _translate('recordButtonTapHint');
  String get recording => _translate('recording');
  String get releaseToSend => _translate('releaseToSend');
  String get recordingTooShort => _translate('recordingTooShort');
  String get microphonePermissionDenied =>
      _translate('microphonePermissionDenied');
  String get saveFailedRetry => _translate('saveFailedRetry');
  String get emotionInputTitle => _translate('emotionInputTitle');
  String get emotionInputHint => _translate('emotionInputHint');
  String get emotionInputSave => _translate('emotionInputSave');
  String get emotionInputAnalyze => _translate('emotionInputAnalyze');
  String get emotionGrantPermissionFirst =>
      _translate('emotionGrantPermissionFirst');
  String get emotionEnterContentBeforeSave =>
      _translate('emotionEnterContentBeforeSave');
  String get emotionEnterContentBeforeAnalyze =>
      _translate('emotionEnterContentBeforeAnalyze');
  String get emotionEmptyInputCannotContinue =>
      _translate('emotionEmptyInputCannotContinue');
  String get emotionEmptyInputCannotSave =>
      _translate('emotionEmptyInputCannotSave');
  String get emotionFinishingRecording =>
      _translate('emotionFinishingRecording');
  String get emotionTranscriptionManualFallback =>
      _translate('emotionTranscriptionManualFallback');
  String get homeGreetingMorning => _translate('homeGreetingMorning');
  String get homeGreetingAfternoon => _translate('homeGreetingAfternoon');
  String get homeGreetingEvening => _translate('homeGreetingEvening');
  String get homeContentTooShortRetry => _translate('homeContentTooShortRetry');
  String get homeSavingRecord => _translate('homeSavingRecord');
  String get homeSaveCancelled => _translate('homeSaveCancelled');
  String get homeRecordSaved => _translate('homeRecordSaved');
  String get homeTranscriptionPending => _translate('homeTranscriptionPending');
  String get homeNoTranscriptionFallback =>
      _translate('homeNoTranscriptionFallback');
  String get homeRecordPrompt => _translate('homeRecordPrompt');
  String get homeStartVoiceRecord => _translate('homeStartVoiceRecord');
  String get homeOpenVoiceInputHint => _translate('homeOpenVoiceInputHint');
  String get moodPickerTitle => _translate('moodPickerTitle');
  String get moodPickerSubtitle => _translate('moodPickerSubtitle');
  String get moodHappy => _translate('moodHappy');
  String get moodCalm => _translate('moodCalm');
  String get moodLoved => _translate('moodLoved');
  String get moodSad => _translate('moodSad');
  String get moodAnnoyed => _translate('moodAnnoyed');
  String get moodAnxious => _translate('moodAnxious');
  String get moodTired => _translate('moodTired');
  String get moodConfused => _translate('moodConfused');
  String get selectLanguage => _translate('selectLanguage');

  // Export screen
  String get exportSelectContent => _translate('exportSelectContent');
  String get exportSelectFormat => _translate('exportSelectFormat');
  String get exportDateRange => _translate('exportDateRange');
  String get exportRecords => _translate('exportRecords');
  String get exportInsights => _translate('exportInsights');
  String get exportFormatMarkdownDesc => _translate('exportFormatMarkdownDesc');
  String get exportFormatCsvDesc => _translate('exportFormatCsvDesc');
  String get exportFormatJsonDesc => _translate('exportFormatJsonDesc');
  String get exportRange7Days => _translate('exportRange7Days');
  String get exportRange30Days => _translate('exportRange30Days');
  String get exportRange3Months => _translate('exportRange3Months');
  String get exportRangeAll => _translate('exportRangeAll');
  String get exportCustomRange => _translate('exportCustomRange');
  String get exportPreview => _translate('exportPreview');
  String get exportPreviewContent => _translate('exportPreviewContent');
  String get exportPreviewFormat => _translate('exportPreviewFormat');
  String get exportPreviewRange => _translate('exportPreviewRange');
  String get exportPreviewFile => _translate('exportPreviewFile');
  String get exportNoSelection => _translate('exportNoSelection');
  String get exportButton => _translate('exportButton');
  String get exportSuccess => _translate('exportSuccess');
  String get exportNoData => _translate('exportNoData');
  String get exportFailed => _translate('exportFailed');
  String get exportShareText => _translate('exportShareText');
  String get exportContentPreview => _translate('exportContentPreview');
  String get exportLoadingData => _translate('exportLoadingData');
  String get exportEmptyTitle => _translate('exportEmptyTitle');
  String get exportEmptySubtitle => _translate('exportEmptySubtitle');
  String get exportActionShare => _translate('exportActionShare');
  String get exportActionDone => _translate('exportActionDone');

  // Pro 订阅相关
  String get pro => _translate('pro');
  String get proMembership => _translate('proMembership');
  String get proPrice => _translate('proPrice');
  String get proPurchaseTitle => _translate('proPurchaseTitle');
  String get proPurchaseSubtitle => _translate('proPurchaseSubtitle');
  String get proFeatureExport => _translate('proFeatureExport');
  String get proFeatureExportDesc => _translate('proFeatureExportDesc');
  String get proFeatureICloud => _translate('proFeatureICloud');
  String get proFeatureICloudDesc => _translate('proFeatureICloudDesc');
  String get proSubscribeButton => _translate('proSubscribeButton');
  String get proRestorePurchase => _translate('proRestorePurchase');
  String get proAlreadySubscribed => _translate('proAlreadySubscribed');
  String get proSubscribeSuccess => _translate('proSubscribeSuccess');
  String get proSubscribeFailed => _translate('proSubscribeFailed');
  String get proProductNotAvailable => _translate('proProductNotAvailable');
  String get proPriceRetry => _translate('proPriceRetry');
  String get proRequired => _translate('proRequired');
  String get proRestoreNone => _translate('proRestoreNone');
  String get proSubscribeNow => _translate('proSubscribeNow');
  String get proPerMonth => _translate('proPerMonth');
  String get proSubscriptionNote => _translate('proSubscriptionNote');
  String get debugMode => _translate('debugMode');
  String get debugModeSubtitle => _translate('debugModeSubtitle');

  // Methods with parameters

  String exportRecordsCount(int count) {
    if (locale.languageCode == 'en') return '$count records';
    return '共 $count 条记录';
  }

  String exportInsightsCount(int count) {
    if (locale.languageCode == 'en') return '$count reports';
    return '共 $count 份报告';
  }

  String exportPreviewRecords(int count) {
    if (locale.languageCode == 'en') return '$count records';
    return '$count 条记录';
  }

  String exportPreviewInsights(int count) {
    if (locale.languageCode == 'en') return '$count insights';
    return '$count 份洞察';
  }

  String exportDone(int records, int insights) {
    if (locale.languageCode == 'en') {
      final parts = <String>[];
      if (records > 0) parts.add('$records records');
      if (insights > 0) parts.add('$insights insights');
      return 'Exported ${parts.join(' and ')}';
    }
    final parts = <String>[];
    if (records > 0) parts.add('$records 条记录');
    if (insights > 0) parts.add('$insights 份洞察');
    return '已导出 ${parts.join(' + ')}';
  }

  String exportExporting(int percent) {
    if (locale.languageCode == 'en') return 'Exporting... $percent%';
    return '导出中... $percent%';
  }

  String exportSavedLocal(String path) {
    if (locale.languageCode == 'en') return 'Saved to: $path';
    return '已保存到本地：$path';
  }

  String recordsCount(int count) {
    if (locale.languageCode == 'en') {
      return '$count records · Tap to change mood';
    }
    return '共 $count 条记录 · 点击修改心情';
  }

  String minutesAgo(int count) {
    if (locale.languageCode == 'en') {
      return '$count min ago';
    }
    return '$count分钟前';
  }

  String hoursAgo(int count) {
    if (locale.languageCode == 'en') {
      return '$count hours ago';
    }
    return '$count小时前';
  }

  // 获取星期几的名称
  String getWeekday(int weekday) {
    final weekdays = [
      monday,
      tuesday,
      wednesday,
      thursday,
      friday,
      saturday,
      sunday,
    ];
    return weekdays[weekday - 1];
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['zh', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
