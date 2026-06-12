import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/network/coze_ai_service.dart';

void main() {
  late CozeAIService service;

  setUpAll(() {
    dotenv.testLoad(
      fileInput: '''
COZE_BASE_URL=https://example.com
COZE_API_TOKEN=test-token
COZE_PROJECT_ID=1
''',
    );
  });

  setUp(() {
    service = CozeAIService();
  });

  test('parses the shared deep-analysis schema and scales emotion intensity',
      () {
    const response = '''
```json
{
  "method": "cognitive_reframe",
  "enough_signal": true,
  "analysis": {
    "core": {
      "observed": {"label": "你脑中的结论", "value": "我一定做不好"},
      "truth": {"label": "事实是", "value": "现在只是结果还没确定"}
    },
    "emotions": [
      {"name": "焦虑", "intensity": 8},
      {"name": "疲惫", "intensity": 65}
    ]
  },
  "response": {
    "resonance": "你已经把最坏的结果提前扛在身上了。",
    "insight": "担心是警报，不是结论。",
    "micro_action": {"text": "写下一条反证。", "kind": "thought_check"},
    "self_statement": "我可以等事实再下结论。"
  }
}
```
''';

    final result = service.parseDeepAnalysisResponse(
      'cognitiveReframe',
      response,
    );

    expect(result.type, 'cognitiveReframe');
    expect(result.resonance, '你已经把最坏的结果提前扛在身上了。');
    expect(result.emotions.map((item) => item.intensity), [80, 65]);
    expect(result.observedValue, '我一定做不好');
    expect(result.truthValue, '现在只是结果还没确定');
    expect(result.microActionKind, 'thought_check');
  });

  test('self-compassion high face applies savoring fallbacks', () {
    const response = '''
{
  "face": "high",
  "enough_signal": true,
  "analysis": {
    "core": {
      "observed": {"value": "今天终于完成了一个重要项目"},
      "truth": {"value": "这份成果里也有我的投入和能力"}
    },
    "emotions": []
  },
  "response": {
    "resonance": "这个时刻值得多停一会儿。",
    "insight": "你可以认领这份好。",
    "micro_action": {"text": "闭眼重温五秒。"},
    "self_statement": "我值得为自己高兴。"
  }
}
''';

    final result = service.parseDeepAnalysisResponse(
      'selfCompassion',
      response,
    );

    expect(result.face, 'high');
    expect(result.observedLabel, '你匆匆带过的好');
    expect(result.truthLabel, '而这份好里');
    expect(result.microActionKind, 'savoring');
  });

  test('unwraps OpenAI choices message content before parsing', () {
    const response = r'''
{
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "{\n  \"method\": \"self_compassion_savoring\",\n  \"face\": \"low\",\n  \"enough_signal\": false,\n  \"analysis\": {\n    \"core\": {\n      \"observed\": {\"label\": \"你对自己说的话\", \"value\": \"是不是我不够好\"},\n      \"truth\": {\"label\": \"但其实\", \"value\": \"这是对方的选择，不是你这个人的问题\"}\n    },\n    \"emotions\": [{\"name\": \"痛苦\", \"intensity\": 9}]\n  },\n  \"response\": {\n    \"resonance\": \"遇到这种事，太痛了。\",\n    \"insight\": \"先别急着怪自己，好吗？\",\n    \"micro_action\": {\"text\": \"轻轻摸一下自己的胳膊或者胸口，停3秒\", \"kind\": \"self_kindness\"},\n    \"self_statement\": \"这不是我的错\"\n  }\n}"
      },
      "finish_reason": "stop"
    }
  ]
}
''';

    final result = service.parseDeepAnalysisResponse(
      'selfCompassion',
      response,
    );

    expect(result.enoughSignal, isFalse);
    expect(result.resonance, '遇到这种事，太痛了。');
    expect(result.observedValue, '是不是我不够好');
    expect(result.truthValue, '这是对方的选择，不是你这个人的问题');
    expect(result.emotions.single.intensity, 90);
    expect(result.groundedUnderstanding, '先别急着怪自己，好吗？');
    expect(result.oneSmallStep, '轻轻摸一下自己的胳膊或者胸口，停3秒');
    expect(result.steadySentence, '这不是我的错');
  });
}
