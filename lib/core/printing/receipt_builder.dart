import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

import 'receipt_data.dart';

/// Builds ESC/POS bytes for 58mm Bluetooth thermal printers.
class ReceiptBuilder {
  static Future<List<int>> build(
    ReceiptData receipt, {
    PaperSize paper = PaperSize.mm58,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paper, profile);
    final bytes = <int>[];
    final money = NumberFormat('#,##0.00');
    final when = receipt.printedAt ?? DateTime.now();
    final dateFmt = DateFormat('dd MMM yyyy HH:mm');

    bytes.addAll(generator.reset());
    bytes.addAll(
      generator.text(
        'MPOS',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    bytes.addAll(
      generator.text(
        _safe(receipt.title),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(generator.hr());

    bytes.addAll(generator.text(_safe(dateFmt.format(when))));
    if (receipt.docNo.isNotEmpty) {
      bytes.addAll(generator.text(_safe('Doc: ${receipt.docNo}')));
    }
    if (receipt.customerName.isNotEmpty) {
      bytes.addAll(generator.text(_clip(receipt.customerName, 32)));
    }
    if (receipt.room.isNotEmpty) {
      bytes.addAll(generator.text(_safe('Room: ${receipt.room}')));
    }
    if (receipt.tin.isNotEmpty) {
      bytes.addAll(generator.text(_safe('TIN: ${receipt.tin}')));
    }
    bytes.addAll(generator.hr());

    for (final line in receipt.lines) {
      final name = line.name.isNotEmpty ? line.name : line.code;
      bytes.addAll(
        generator.text(
          _clip(name, 32),
          styles: const PosStyles(bold: true),
        ),
      );
      final qtyPart = line.uom.isEmpty
          ? money.format(line.qty)
          : '${money.format(line.qty)} ${_safe(line.uom)}';
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

    bytes.addAll(generator.hr());
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

    bytes.addAll(generator.hr());
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
}
