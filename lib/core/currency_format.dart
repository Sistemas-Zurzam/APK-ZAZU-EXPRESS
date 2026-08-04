import 'package:intl/intl.dart';

final NumberFormat peruvianCurrency = NumberFormat.currency(
  locale: 'es_PE',
  symbol: 'S/',
  decimalDigits: 2,
  customPattern: '¤ #,##0.00',
);
