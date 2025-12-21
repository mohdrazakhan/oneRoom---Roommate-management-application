import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../Models/expense.dart';

class ExpenseExportService {
  /// Convert currency symbol to text code for PDF compatibility
  static String _currencySymbolToCode(String symbol) {
    switch (symbol) {
      case '₹':
        return 'INR';
      case '\$':
        return 'USD';
      case '€':
        return 'EUR';
      case '£':
        return 'GBP';
      case '¥':
        return 'JPY';
      case 'R\$':
        return 'BRL';
      case 'A\$':
        return 'AUD';
      case 'C\$':
        return 'CAD';
      default:
        return symbol; // Return as-is if not recognized
    }
  }

  /// Generate PDF for expense transactions
  static Future<void> generateAndSharePDF({
    required List<Expense> expenses,
    required String roomName,
    required String currency,

    Map<String, String>? memberNames, // uid -> name mapping
  }) async {
    final names = memberNames ?? {};
    final pdf = pw.Document();

    // Convert currency symbol to text code for PDF
    final currencyCode = _currencySymbolToCode(currency);

    // Calculate total expenditure
    final totalExpenditure = expenses.fold<double>(
      0.0,
      (sum, expense) => sum + expense.amount,
    );

    // Group expenses by payer
    final Map<String, List<Expense>> expensesByPayer = {};
    for (final expense in expenses) {
      if (!expensesByPayer.containsKey(expense.paidBy)) {
        expensesByPayer[expense.paidBy] = [];
      }
      expensesByPayer[expense.paidBy]!.add(expense);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Expense Summary',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    roomName,
                    style: const pw.TextStyle(
                      fontSize: 18,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated on: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Divider(thickness: 2),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Total Expenditure
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Expenditure:',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '$currencyCode ${totalExpenditure.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // Transaction Table
            pw.Text(
              'All Transactions',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('Date', isHeader: true),
                    _buildTableCell('Description', isHeader: true),
                    _buildTableCell('Paid By', isHeader: true),
                    _buildTableCell('Amount', isHeader: true),
                  ],
                ),
                // Data rows
                ...expenses.map((expense) {
                  final payerName = names[expense.paidBy] ?? expense.paidBy;
                  return pw.TableRow(
                    children: [
                      _buildTableCell(
                        DateFormat('MMM dd, yyyy').format(expense.createdAt),
                      ),
                      _buildTableCell(expense.description),
                      _buildTableCell(payerName),
                      _buildTableCell(
                        '$currencyCode ${expense.amount.toStringAsFixed(2)}',
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 30),

            // Summary by Member
            pw.Text(
              'Expenditure by Member',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),

            ...expensesByPayer.entries.map((entry) {
              final memberName = names[entry.key] ?? entry.key;
              final memberTotal = entry.value.fold<double>(
                0.0,
                (sum, exp) => sum + exp.amount,
              );
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      memberName,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '$currencyCode ${memberTotal.toStringAsFixed(2)} (${entry.value.length} transactions)',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 20),

            // Footer
            pw.Divider(),
            pw.Text(
              'This is a read-only document generated from One Room app.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ];
        },
      ),
    );

    // Save and share PDF
    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/expense_summary_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Expense Summary - $roomName',
      text: 'Expense summary for $roomName',
    );
  }

  /// Generate Excel for expense transactions
  static Future<void> generateAndShareExcel({
    required List<Expense> expenses,
    required String roomName,
    required String currency,

    Map<String, String>? memberNames,
  }) async {
    final names = memberNames ?? {};
    final excel = excel_pkg.Excel.createExcel();
    final sheet = excel['Expense Summary'];

    // Calculate total
    final totalExpenditure = expenses.fold<double>(
      0.0,
      (sum, expense) => sum + expense.amount,
    );

    // Header
    sheet.appendRow([excel_pkg.TextCellValue('Expense Summary - $roomName')]);
    sheet.appendRow([
      excel_pkg.TextCellValue(
        'Generated: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())}',
      ),
    ]);
    sheet.appendRow([]); // Empty row

    // Total Expenditure
    sheet.appendRow([
      excel_pkg.TextCellValue('Total Expenditure:'),
      excel_pkg.TextCellValue(
        '$currency${totalExpenditure.toStringAsFixed(2)}',
      ),
    ]);
    sheet.appendRow([]); // Empty row

    // Transaction table header
    sheet.appendRow([
      excel_pkg.TextCellValue('Date'),
      excel_pkg.TextCellValue('Description'),
      excel_pkg.TextCellValue('Paid By'),
      excel_pkg.TextCellValue('Amount'),
    ]);

    // Transaction data
    for (final expense in expenses) {
      final payerName = names[expense.paidBy] ?? expense.paidBy;
      sheet.appendRow([
        excel_pkg.TextCellValue(
          DateFormat('MMM dd, yyyy').format(expense.createdAt),
        ),
        excel_pkg.TextCellValue(expense.description),
        excel_pkg.TextCellValue(payerName),
        excel_pkg.TextCellValue(
          '$currency${expense.amount.toStringAsFixed(2)}',
        ),
      ]);
    }

    // Add member summary sheet
    final summarySheet = excel['Summary by Member'];

    summarySheet.appendRow([
      excel_pkg.TextCellValue('Member Name'),
      excel_pkg.TextCellValue('Total Spent'),
      excel_pkg.TextCellValue('Transactions'),
    ]);

    final Map<String, List<Expense>> expensesByPayer = {};
    for (final expense in expenses) {
      if (!expensesByPayer.containsKey(expense.paidBy)) {
        expensesByPayer[expense.paidBy] = [];
      }
      expensesByPayer[expense.paidBy]!.add(expense);
    }

    for (final entry in expensesByPayer.entries) {
      final memberName = names[entry.key] ?? entry.key;
      final memberTotal = entry.value.fold<double>(
        0.0,
        (sum, exp) => sum + exp.amount,
      );
      summarySheet.appendRow([
        excel_pkg.TextCellValue(memberName),
        excel_pkg.TextCellValue('$currency${memberTotal.toStringAsFixed(2)}'),
        excel_pkg.IntCellValue(entry.value.length),
      ]);
    }

    // Save and share Excel
    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/expense_summary_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Expense Summary - $roomName',
        text: 'Expense summary for $roomName',
      );
    }
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
