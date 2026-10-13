import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/friend.dart';
import '../services/pdf_service.dart';

class StatementDialog extends StatelessWidget {
  final Friend friend;
  final bool isDark;

  const StatementDialog({
    super.key,
    required this.friend,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final sanitizedName =
        friend.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: isDark ? const Color(0xFF111111) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              children: [
                Text(
                  "STATEMENT",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  friend.name.toUpperCase(),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                IconButton(
                  tooltip: "Share PDF",
                  icon: const Icon(Icons.share, size: 18),
                  onPressed: () => PdfService.shareStatementPdf(friend),
                ),
                IconButton(
                  tooltip: "Close",
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: PdfPreview(
                build: (format) => PdfService.generateStatementPdf(friend),
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                loadingWidget: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD71921)),
                ),
                pdfFileName: 'ledger_${sanitizedName}_statement.pdf',
                previewPageMargin: const EdgeInsets.all(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
