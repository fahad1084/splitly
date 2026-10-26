import 'package:home_widget/home_widget.dart';
import 'package:splitly/core/utils/app_logger.dart';

class HomeWidgetService {
  static Future<void> updateBalance({
    required double totalOwed,
    required double totalOwe,
    required String currency,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>(
          'owed_text', '$currency ${totalOwed.toStringAsFixed(0)}');
      await HomeWidget.saveWidgetData<String>(
          'owe_text', '$currency ${totalOwe.toStringAsFixed(0)}');
      await HomeWidget.updateWidget(
        name: 'SplitlyWidgetProvider',
        androidName: 'SplitlyWidgetProvider',
      );
    } catch (e) {
      logDebug('=== HOME WIDGET UPDATE ERROR: $e ===');
    }
  }
}