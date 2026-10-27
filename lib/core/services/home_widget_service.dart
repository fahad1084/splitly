import 'package:home_widget/home_widget.dart';
import 'package:splitly/core/utils/app_logger.dart';

class HomeWidgetService {
  // Texts come from formatTotals(): one amount per currency, e.g.
  // "PKR 5,000.00 · USD 20.00" — currencies are never added together.
  static Future<void> updateBalance({
    required String owedText,
    required String oweText,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('owed_text', owedText);
      await HomeWidget.saveWidgetData<String>('owe_text', oweText);
      await HomeWidget.updateWidget(
        name: 'SplitlyWidgetProvider',
        androidName: 'SplitlyWidgetProvider',
      );
    } catch (e) {
      logDebug('=== HOME WIDGET UPDATE ERROR: $e ===');
    }
  }
}