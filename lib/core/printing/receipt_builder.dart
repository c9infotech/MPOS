import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

import 'receipt_data.dart';
import 'receipt_paper.dart';

/// Builds ESC/POS bytes for thermal printers (58mm / 72mm / 80mm).
class ReceiptBuilder {
  static Future<List<int>> build(
    ReceiptData receipt, {
    PaperSize paper = PaperSize.mm58,
    bool includeCustomerSign = true,
    bool plainLayout = false,
    bool setPrintWidth = false,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paper, profile);
    final bytes = <int>[];
    final money = NumberFormat('#,##0.00');
    final when = receipt.printedAt ?? DateTime.now();
    final dateFmt = DateFormat('dd MMM yyyy HH:mm');
    final maxChars = maxCharsForPaper(paper);

    bytes.addAll(generator.reset());
    if (setPrintWidth) {
      bytes.addAll(escPosSetPrintWidth(paper));
    }
    // Company header (replaces MPOS / Sales Receipt).
    bytes.addAll(
      generator.text(
        'Karibu Camps and Lodges Ltd',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
      ),
    );
    bytes.addAll(
      generator.text(
        'P.O.Box 174,',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        'Arusha, Tanzania',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        'TIN No. 135-228-494',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        'VRN No: 40-027743-X',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    if (receipt.camp.isNotEmpty) {
      bytes.addAll(
        generator.text(
          _safe(receipt.camp),
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size1,
          ),
        ),
      );
    }
    bytes.addAll(
      generator.text(
        'Sales Invoice',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(generator.hr());

    bytes.addAll(generator.text(_safe(dateFmt.format(when))));
    if (receipt.docNo.isNotEmpty) {
      bytes.addAll(generator.text(_safe('Doc No: ${receipt.docNo}')));
    }
    if (receipt.agent.trim().isNotEmpty) {
      bytes.addAll(generator.text(_safe('Agent: ${receipt.agent.trim()}')));
    }
    final clientName = receipt.clientName.trim().isNotEmpty
        ? receipt.clientName.trim()
        : receipt.customerName.trim();
    if (clientName.isNotEmpty) {
      bytes.addAll(
        generator.text(_clip('Client Name: $clientName', maxChars)),
      );
    }
    if (receipt.wbNo.trim().isNotEmpty) {
      bytes.addAll(generator.text(_safe('WBNo: ${receipt.wbNo.trim()}')));
    } else if (receipt.bookingReference.trim().isNotEmpty) {
      // Legacy / cart receipts that still use bookingReference as WBNo.
      bytes.addAll(
        generator.text(
          _safe('WBNo: ${receipt.bookingReference.trim()}'),
        ),
      );
    }
    if (receipt.tin.trim().isNotEmpty) {
      bytes.addAll(generator.text(_safe('TIN No: ${receipt.tin.trim()}')));
    }
    if (receipt.room.trim().isNotEmpty) {
      bytes.addAll(generator.text(_safe('Room No: ${receipt.room.trim()}')));
    }
    bytes.addAll(generator.hr());

    for (final line in receipt.lines) {
      final name = line.name.isNotEmpty ? line.name : line.code;
      bytes.addAll(
        generator.text(
          _clip(name, maxChars),
          styles: const PosStyles(bold: true),
        ),
      );
      final qtyPart = line.uom.isEmpty
          ? money.format(line.qty)
          : '${money.format(line.qty)} ${_safe(line.uom)}';
      if (plainLayout) {
        bytes.addAll(
          generator.text(
            _lineLeftRight(
              '$qtyPart x ${money.format(line.price)}',
              money.format(line.lineTotal),
              maxChars,
            ),
          ),
        );
      } else {
        bytes.addAll(
          generator.row([
            PosColumn(
              text: _safe('$qtyPart x ${money.format(line.price)}'),
              width: 7,
              styles: const PosStyles(align: PosAlign.left),
            ),
            PosColumn(
              text: money.format(line.lineTotal),
              width: 5,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]),
        );
      }
    }

    bytes.addAll(generator.hr());
    if (plainLayout) {
      bytes.addAll(
        generator.text(
          _lineLeftRight(
            'Subtotal',
            '${receipt.currency} ${money.format(receipt.subtotal)}',
            maxChars,
          ),
        ),
      );
      bytes.addAll(
        generator.text(
          _lineLeftRight(
            'Tax',
            '${receipt.currency} ${money.format(receipt.tax)}',
            maxChars,
          ),
        ),
      );
      bytes.addAll(
        generator.text(
          _lineLeftRight(
            'TOTAL',
            '${receipt.currency} ${money.format(receipt.total)}',
            maxChars,
          ),
          styles: const PosStyles(bold: true),
        ),
      );
    } else {
      bytes.addAll(
        generator.row([
          PosColumn(text: 'Subtotal', width: 7),
          PosColumn(
            text: _safe('${receipt.currency} ${money.format(receipt.subtotal)}'),
            width: 5,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
      bytes.addAll(
        generator.row([
          PosColumn(text: 'Tax', width: 7),
          PosColumn(
            text: _safe('${receipt.currency} ${money.format(receipt.tax)}'),
            width: 5,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
      bytes.addAll(
        generator.row([
          PosColumn(
            text: 'TOTAL',
            width: 7,
            styles: const PosStyles(bold: true),
          ),
          PosColumn(
            text: _safe('${receipt.currency} ${money.format(receipt.total)}'),
            width: 5,
            styles: const PosStyles(align: PosAlign.right, bold: true),
          ),
        ]),
      );
    }

    if (receipt.paymentMode.isNotEmpty) {
      bytes.addAll(generator.text(_safe('Pay: ${receipt.paymentMode}')));
    }
    if (receipt.paidAmount != null) {
      bytes.addAll(
        generator.text(
          _safe(
            'Paid: ${receipt.currency} ${money.format(receipt.paidAmount)}',
          ),
        ),
      );
    }

    final orderNumbers = receipt.orderNumbers
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList(growable: false);
    if (orderNumbers.isNotEmpty) {
      bytes.addAll(generator.hr());
      bytes.addAll(
        generator.text(
          _safe("Order Number's:"),
          styles: const PosStyles(bold: true),
        ),
      );
      // Print each doc number on its own line for bulk payments.
      for (final orderNo in orderNumbers) {
        bytes.addAll(generator.text(_safe(orderNo)));
      }
    }

    if (receipt.waiter.trim().isNotEmpty) {
      if (orderNumbers.isEmpty) {
        bytes.addAll(generator.hr());
      }
      bytes.addAll(
        generator.text(_safe('Waiter: ${receipt.waiter.trim()}')),
      );
    }

    bytes.addAll(generator.hr());
    if (includeCustomerSign) {
      bytes.addAll(
        generator.text(
          _safe(receipt.footer),
          styles: const PosStyles(align: PosAlign.left, bold: true),
        ),
      );
      // Blank space for customer handwritten signature.
      bytes.addAll(generator.feed(5));
      bytes.addAll(generator.text('______________________________'));
      bytes.addAll(generator.feed(2));
    } else {
      bytes.addAll(generator.feed(2));
    }
    bytes.addAll(generator.cut());
    return bytes;
  }

  /// Printers use Latin-1; strip/replace characters that would crash encoding.
  static String _safe(String value) {
    var text = value
        .replaceAll('…', '...')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('•', '*')
        .replaceAll('\u00A0', ' ');
    final buffer = StringBuffer();
    for (final unit in text.runes) {
      if (unit <= 0xFF) {
        buffer.writeCharCode(unit);
      } else {
        buffer.write('?');
      }
    }
    return buffer.toString();
  }

  static String _clip(String value, int max) {
    final safe = _safe(value.trim());
    if (safe.length <= max) return safe;
    return '${safe.substring(0, max - 3)}...';
  }

  /// Single line with left and right text, padded to [width] chars (58mm-safe).
  static String _lineLeftRight(String left, String right, int width) {
    final l = _safe(left.trim());
    final r = _safe(right.trim());
    if (l.length + r.length >= width) {
      return _clip('$l $r', width);
    }
    return l + (' ' * (width - l.length - r.length)) + r;
  }
}
