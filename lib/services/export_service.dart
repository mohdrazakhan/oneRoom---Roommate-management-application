import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import '../Models/personal_expense.dart';

class ExportService {
  Future<void> exportExpensesToPdf(List<PersonalExpense> expenses) async {
    final pdf = pw.Document();

    // Sort by date
    expenses.sort((a, b) => b.date.compareTo(a.date));

    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final double total = expenses.fold(0, (sum, e) => sum + e.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Personal Expense Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text('Generated: ${formatter.format(DateTime.now())}'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Total Spending: ${total.toStringAsFixed(2)} INR',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Category', 'Description', 'Mode', 'Amount'],
              data: expenses
                  .map(
                    (e) => [
                      formatter.format(e.date),
                      e.category,
                      e.description,
                      e.paymentMode,
                      e.amount.toStringAsFixed(2),
                    ],
                  )
                  .toList(),
            ),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/expense_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Here is my expense report.');
  }

  Future<void> exportExpensesToExcel(List<PersonalExpense> expenses) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];

    sheetObject.appendRow([
      TextCellValue('Date'),
      TextCellValue('Category'),
      TextCellValue('Description'),
      TextCellValue('Mode'),
      TextCellValue('Amount'),
    ]);

    expenses.sort((a, b) => b.date.compareTo(a.date));
    final DateFormat formatter = DateFormat('yyyy-MM-dd');

    for (var e in expenses) {
      sheetObject.appendRow([
        TextCellValue(formatter.format(e.date)),
        TextCellValue(e.category),
        TextCellValue(e.description),
        TextCellValue(e.paymentMode),
        DoubleCellValue(e.amount),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes == null) return;

    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/expense_report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );

    await file.create(recursive: true);
    await file.writeAsBytes(fileBytes);

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Here is my expense report (Excel).');
  }
}
