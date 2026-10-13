import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/friend.dart';

class PdfService {
  static Future<Uint8List> generateStatementPdf(Friend friend) async {
    final pdf = pw.Document();

    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    double totalLent = 0.0;
    double totalBorrowed = 0.0;
    for (var tx in friend.transactions) {
      if (tx.amount >= 0) {
        totalLent += tx.amount;
      } else {
        totalBorrowed += tx.amount.abs();
      }
    }

    final redColor = PdfColor.fromInt(0xFFD71921);
    final greenColor = PdfColor.fromInt(0xFF2E7D32);
    final greyColor = PdfColor.fromInt(0xFF757575);
    final lightGrey = PdfColor.fromInt(0xFFF5F5F5);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 4,
                      height: 24,
                      color: redColor,
                      margin: const pw.EdgeInsets.only(right: 8),
                    ),
                    pw.Text(
                      'LEDGER',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Text(
                      '|   ${friend.name.toUpperCase()}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  dateStr,
                  style: pw.TextStyle(fontSize: 11, color: greyColor),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Ledger App',
                  style: pw.TextStyle(fontSize: 9, color: greyColor),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 9, color: greyColor),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          double cumulative = 0.0;

          return [
            // --- TOTALS SUMMARY ---
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: pw.BoxDecoration(
                color: lightGrey,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'TOTAL LENT',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: greyColor,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '+${totalLent.toStringAsFixed(2)} MAD',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: greenColor,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'TOTAL BORROWED',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: greyColor,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '-${totalBorrowed.toStringAsFixed(2)} MAD',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: redColor,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'NET BALANCE',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: greyColor,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${friend.amountOwed >= 0 ? '+' : ''}${friend.amountOwed.toStringAsFixed(2)} MAD',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: friend.amountOwed >= 0 ? greenColor : redColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // --- TRANSACTIONS TABLE ---
            pw.Text(
              'TRANSACTIONS',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 6),

            pw.TableHelper.fromTextArray(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(color: lightGrey, width: 0.5),
                bottom: pw.BorderSide(color: lightGrey, width: 0.5),
              ),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
              headerHeight: 22,
              cellHeight: 22,
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              columnWidths: {
                0: const pw.FixedColumnWidth(24),
                1: const pw.FixedColumnWidth(68),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FixedColumnWidth(75),
                4: const pw.FixedColumnWidth(75),
              },
              headers: ['#', 'DATE', 'REASON', 'AMOUNT', 'BALANCE'],
              data: List<List<String>>.generate(
                friend.transactions.length,
                (index) {
                  final tx = friend.transactions[index];
                  cumulative += tx.amount;
                  final dStr =
                      '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}';
                  final amtStr =
                      '${tx.amount >= 0 ? '+' : ''}${tx.amount.toStringAsFixed(2)}';
                  final balStr =
                      '${cumulative >= 0 ? '+' : ''}${cumulative.toStringAsFixed(2)}';
                  final reasonStr =
                      tx.isEdited ? '${tx.reason} (edited)' : tx.reason;

                  return [
                    '${index + 1}',
                    dStr,
                    reasonStr,
                    '$amtStr MAD',
                    '$balStr MAD',
                  ];
                },
              ),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),

            // --- BORROWED & LENT OBJECTS (if any) ---
            if (friend.borrowedItems.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              pw.Text(
                'OBJECTS',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: lightGrey, width: 0.5),
                  bottom: pw.BorderSide(color: lightGrey, width: 0.5),
                ),
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.black),
                headerHeight: 22,
                cellHeight: 22,
                cellPadding:
                    const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FixedColumnWidth(80),
                  2: const pw.FixedColumnWidth(70),
                },
                headers: ['ITEM', 'TYPE', 'STATUS'],
                data: List<List<String>>.generate(
                  friend.borrowedItems.length,
                  (index) {
                    final item = friend.borrowedItems[index];
                    final type = item.isLentByMe ? 'Lent out' : 'Borrowed';
                    final status = item.isReturned ? 'Returned' : 'Active';
                    return [item.name, type, status];
                  },
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> shareStatementPdf(Friend friend) async {
    final bytes = await generateStatementPdf(friend);
    final sanitizedName =
        friend.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'ledger_${sanitizedName}_statement.pdf',
    );
  }
}
