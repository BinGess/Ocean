/// 获取周洞察列表用例

import '../entities/weekly_insight.dart';
import '../repositories/insight_repository.dart';
import 'base_usecase.dart';

class GetWeeklyInsightsParams {
  final int? limit;

  GetWeeklyInsightsParams({this.limit});
}

class GetWeeklyInsightsUseCase
    extends UseCase<List<WeeklyInsight>, GetWeeklyInsightsParams> {
  final InsightRepository insightRepository;

  GetWeeklyInsightsUseCase({required this.insightRepository});

  @override
  Future<List<WeeklyInsight>> call(GetWeeklyInsightsParams params) async {
    if (params.limit != null) {
      return await insightRepository.getRecentInsights(limit: params.limit!);
    } else {
      return await insightRepository.getAllWeeklyInsights();
    }
  }
}
