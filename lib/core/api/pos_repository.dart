import 'dart:convert';

import '../api/api_client.dart';
import '../auth/auth_service.dart';
import '../config/config_loader.dart';
import '../../models/customer.dart';
import '../../models/delivery_note.dart';
import '../../models/payment_mode.dart';
import '../../models/pos_draft.dart';
import '../../models/product.dart';

class PosRepository {
  PosRepository(this._api, this._auth);

  final ApiClient _api;
  final AuthService _auth;

  AuthSession get _session {
    final session = _auth.session;
    if (session == null) {
      throw ApiException('Session expired. Please login again.');
    }
    return session;
  }

  Future<void> login({
    required String username,
    required String password,
    String? companyDb,
  }) async {
    // Same as Vue: CompanyDB from config `companydb` when not provided.
    final db = (companyDb == null || companyDb.trim().isEmpty)
        ? ConfigLoader.current.companyDb
        : companyDb.trim();

    // Route login (and the rest of the session) to this company's base URL.
    ConfigLoader.useApiUrlForCompany(db);
    final apiUrl = ConfigLoader.apiUrl;

    // Exact Vue payload shape (UserLogin.vue login()).
    final param = <String, dynamic>{
      'UserName': username,
      'Password': password,
      'companydb': db,
    };

    final data = await _api.post('Login', param);

    // Exact Vue handling:
    // if statusCode == 2 → error
    // else if responseData.error → error
    // else success (save UI + db + navigate)
    final statusCode = data['statusCode'];
    if (statusCode == 2 || statusCode == '2') {
      throw ApiException(ApiClient.extractError(data));
    }

    final responseData = data['responseData'];
    if (responseData is Map && responseData['error'] != null) {
      throw ApiException(ApiClient.extractError(data));
    }
    if (responseData is! Map<String, dynamic>) {
      throw ApiException(
        data['statusMessage']?.toString() ?? 'Invalid login response.',
      );
    }

    await _auth.saveSession(
      ui: responseData,
      database: db,
      apiUrl: apiUrl,
    );
  }

  Future<List<Customer>> fetchCustomers() async {
    final data = await _api.post('CustomerDetails', {
      'UserCode': _session.userCode,
    });
    final list = data['responseData'];
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Customer.fromJson)
        .toList();
  }

  Future<List<Product>> fetchProducts() async {
    final data = await _api.post('PriceDetails', {
      'UserCode': _session.employeeId,
      'ItemCode': '',
      'CustomerCode': '',
      'Database': _session.database,
    });
    final list = data['responseData'];
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Product.fromJson)
        .toList();
  }

  Future<String> createDeliveryNote({
    required Customer customer,
    required String currency,
    required List<CartLine> lines,
  }) async {
    final today = _today();
    final details = lines
        .map(
          (line) => {
            'ItemCode': line.product.itemCode,
            'Quantity': '${line.qty}',
            'Warehouse': customer.whsCode,
            'CartPrice': line.cartPrice,
            'CartUOM': line.cartUom,
            'UnitPrice': '${line.cartPrice}',
            'usduomPrice': line.product.usdPrice,
            'tzsPrice': line.product.tzsPrice,
            'UoM': line.cartUom,
            'Currency': currency,
            'U_Charged': line.chargeable ? 'TRUE' : 'FALSE',
          },
        )
        .toList();

    final data = await _api.post('DeliveryNote', {
      'CardCode': customer.cardCode,
      'DocDate': today,
      'DocDueDate': today,
      'U_TINNo': customer.tin,
      'U_Rooming': customer.room,
      'U_BookingName': customer.clientName,
      'Reference2': customer.wbnNo.isNotEmpty
          ? customer.wbnNo
          : customer.contact,
      'agent': customer.agent,
      'clientName': customer.clientName,
      'wbnNo': customer.wbnNo,
      'cashSalesNo': customer.cashSalesNo,
      'roomNo': customer.room,
      'tinNo': customer.tin,
      'Comments': 'MPOS mobile',
      'SessionId': _session.sessionId,
      'DeliveryNotePostingDetails': details,
    });

    if (data['statusCode'] != 0) {
      throw ApiException(ApiClient.extractError(data));
    }

    return _extractDocNum(data) ?? '';
  }

  /// Reads document number from API response (DeliveryNote / payment).
  String? _extractDocNum(Map<String, dynamic> data) {
    final response = data['responseData'];
    if (response is Map<String, dynamic>) {
      final fromMap = _docNumFromMap(response);
      if (fromMap != null) return fromMap;
    }
    if (response is List) {
      for (final item in response) {
        if (item is Map<String, dynamic>) {
          final fromItem = _docNumFromMap(item);
          if (fromItem != null) return fromItem;
        }
      }
    }
    return _docNumFromMap(data);
  }

  String? _docNumFromMap(Map<String, dynamic> json) {
    for (final key in [
      'docNum',
      'DocNum',
      'docnum',
      'documentNo',
      'DocumentNo',
      'docEntry',
      'DocEntry',
    ]) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  Future<void> insertDraft({
    required int tableNumber,
    required String subdivision,
    required String currency,
    required List<CartLine> lines,
    Customer? customer,
  }) async {
    final payloadCustomer = customer == null
        ? {
            'cardCode': '',
            'cardName': '',
            'customerName': '',
            'tin': '',
            'tinNo': '',
            'currency': currency,
            'room': '',
            'roomNo': '',
            'contact': '',
            'whsCode': '',
            'agent': '',
            'clientName': '',
            'wbnNo': '',
            'cashSalesNo': '',
          }
        : {
            'cardCode': customer.cardCode,
            'cardName': customer.cardName,
            'customerName': customer.customerName,
            'tin': customer.tin,
            'tinNo': customer.tin,
            'currency': customer.currency,
            'room': customer.room,
            'roomNo': customer.room,
            'contact': customer.contact,
            'whsCode': customer.whsCode,
            'agent': customer.agent,
            'clientName': customer.clientName,
            'wbnNo': customer.wbnNo,
            'cashSalesNo': customer.cashSalesNo,
          };
    final payload = {
      'tableNumber': tableNumber,
      'subdivision': subdivision,
      'currency': currency,
      'customer': payloadCustomer,
      'lines': lines
          .map(
            (line) => {
              'product': {
                'itemCode': line.product.itemCode,
                'itemName': line.product.itemName,
                'isdelivered': line.isDelivered,
                'isDelivered': line.isDelivered,
                'salUnitMsr': line.product.salUnitMsr,
                'uomName': line.product.uomName,
                'usdPrice': line.product.usdPrice,
                'tzsPrice': line.product.tzsPrice,
                'usduomPrice': line.product.usduomPrice,
                'tzsuomPrice': line.product.tzsuomPrice,
                'qtyPerUom': line.product.qtyPerUom,
                'itemUom': line.product.itemUom,
                'isPriceEditable': line.product.isPriceEditable,
                'premiumDrinks': line.product.isPremiumDrink ? 'Y' : 'N',
                'type': line.product.type,
                // Never send null/HTML image payloads — backend JSON parser fails on "<".
                'image': _safeImageValue(line.product.image),
              },
              'qty': line.qty,
              'cartPrice': line.cartPrice,
              'cartUom': line.cartUom,
              'chargeable': line.chargeable,
              'isDelivered': line.isDelivered,
              'IsDelivered': line.isDelivered,
              'withGst': line.withGst,
            },
          )
          .toList(),
    };

    final data = await _api.post('InsertDraft', payload);
    if (!_isSuccessStatus(data['statusCode'])) {
      throw ApiException(ApiClient.extractError(data));
    }
  }

  Future<List<SavedPosDraft>> fetchDrafts({String draftId = ''}) async {
    final data = await _api.post('GetDraft', {'DraftID': draftId});
    if (!_isSuccessStatus(data['statusCode'])) {
      throw ApiException(ApiClient.extractError(data));
    }
    final rows = _normalizeResponseData(data['responseData']);
    final listRows = rows is List
        ? rows
        : (rows is Map ? [rows] : const []);
    if (listRows.isEmpty) return [];
    final now = DateTime.now();
    final parsed = <SavedPosDraft>[];
    for (final rowRaw in listRows) {
      final row = _asMap(rowRaw);
      if (row == null) continue;
      final linesRaw = row['lines'];
      final lineList = linesRaw is List
          ? linesRaw
              .map(_asMap)
              .whereType<Map<String, dynamic>>()
              .map(_draftLine)
              .toList()
          : <CartLine>[];
      parsed.add(SavedPosDraft(
        id: (row['draftId'] ?? row['id'] ?? '').toString(),
        slot: PosDraftSlot(
          tableNumber: _toInt(row['tableNumber']),
          subdivision: (row['subdivision'] ?? '').toString(),
        ),
        lines: lineList,
        currency: (row['currency'] ?? 'USD').toString(),
        savedAt: now,
        customer: _asMap(row['customer']) == null
            ? null
            : Customer.fromJson(_asMap(row['customer'])!),
      ));
    }
    return parsed;
  }

  Future<void> deleteDraft(String draftId) async {
    final data = await _api.post('DeleteDraft', {'DraftID': draftId});
    if (!_isSuccessStatus(data['statusCode'])) {
      throw ApiException(ApiClient.extractError(data));
    }
  }

  Future<List<DeliveryNote>> fetchDeliveryNotes({String? wbNo}) async {
    final body = <String, dynamic>{
      'UserCode': _session.userCode,
      'Index': 1,
    };
    final wb = wbNo?.trim() ?? '';
    if (wb.isNotEmpty) {
      body['u_WBNO'] = wb;
      body['WBno'] = wb;
    }
    final data = await _api.post('DeliveryNoteDetails', body);
    final list = data['responseData'];
    if (list is! List) return [];
    final notes = <DeliveryNote>[];
    for (final row in list) {
      final map = _asMap(row);
      if (map == null) continue;
      notes.add(DeliveryNote.fromJson(map));
    }
    if (wb.isEmpty) return notes;
    final needle = wb.toLowerCase();
    return notes
        .where((n) => n.wbNo.toLowerCase().contains(needle))
        .toList(growable: false);
  }

  Future<List<PaymentMode>> fetchPaymentModes({
    required String customerCode,
  }) async {
    final data = await _api.post('PaymentMode', {
      'CustomerCode': customerCode.trim(),
    });
    final list = data['responseData'];
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(PaymentMode.fromJson)
        .toList();
  }

  Future<void> savePayment({
    required List<DeliveryNote> notes,
    required List<({PaymentMode mode, double amount})> payments,
    required String chargeTo,
  }) async {
    if (notes.isEmpty) {
      throw ApiException('No sales selected.');
    }
    final validPayments =
        payments.where((p) => p.amount > 0).toList(growable: false);
    if (validPayments.isEmpty) {
      throw ApiException('Enter at least one payment amount.');
    }
    final charge = chargeTo.trim();
    if (charge.isEmpty) {
      throw ApiException('Select Charge to (Agent or Client).');
    }

    final first = notes.first;
    final invoiceDetails = <Map<String, dynamic>>[];
    for (final note in notes) {
      for (final item in note.items) {
        invoiceDetails.add({
          'ItemCode': item.itemCode,
          'Quantity': item.quantity.toInt(),
          'Warehouse': item.whsCode,
          'UnitPrice': item.price,
          'BaseType': item.baseType,
          'BaseEntry': item.baseEntry,
          'BaseLine': item.baseLine,
          'Chargeable': item.charged ? 'No' : 'Yes',
        });
      }
    }

    final data = await _api.post('SalesInvoiceWithPayment', {
      'CardCode': first.cardCode,
      'DocDate': first.docDateIso,
      'DocDueDate': first.docDueDateIso,
      'SalesPersonCode': first.salespersonCode,
      'U_TINNo': first.tinNo,
      'TrackingNumber': first.trackingNumber,
      'Comments': first.comments,
      'SessionId': _session.sessionId,
      'u_chargeto': charge,
      'SalesInvoiceDetails': invoiceDetails,
      'PaymentInvoice': validPayments
          .map(
            (p) => {
              'Branch': p.mode.branch,
              'PaymentMode': p.mode.paymentMode,
              'CashSum': p.amount.toStringAsFixed(2),
            },
          )
          .toList(),
    });

    if (data['statusCode'] != 0) {
      throw ApiException(ApiClient.extractError(data));
    }
  }

  String _today() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }

  CartLine _draftLine(Map<String, dynamic> json) {
    final productJson = _asMap(json['product']) ?? const <String, dynamic>{};
    final product = Product.fromJson(productJson);
    final chargeable = product.isPremiumDrink
        ? true
        : _toBool(json['chargeable']);
    final qtyRaw = json['qty'];
    final qty = qtyRaw is num
        ? qtyRaw.toInt()
        : (double.tryParse(qtyRaw?.toString() ?? '1') ?? 1).toInt();
    return CartLine(
      product: product,
      qty: qty < 1 ? 1 : qty,
      cartPrice: _toDouble(json['cartPrice']),
      cartUom: (json['cartUom'] ?? '').toString(),
      chargeable: chargeable,
      isDelivered: _toBool(
        json['isDelivered'] ??
            json['IsDelivered'] ??
            json['delivered'] ??
            productJson['isdelivered'] ??
            productJson['isDelivered'],
      ),
      withGst: _toDouble(json['withGst']),
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    final raw = value?.toString().trim().toLowerCase();
    return raw == 'true' || raw == '1' || raw == 'y';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _isSuccessStatus(dynamic statusCode) {
    if (statusCode is num) return statusCode.toInt() == 0;
    return statusCode?.toString().trim() == '0';
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  dynamic _normalizeResponseData(dynamic raw) {
    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return const [];
      try {
        return jsonDecode(text);
      } catch (_) {
        return const [];
      }
    }
    return raw;
  }

  /// Backend fails when image is null or contains HTML (`<...>`).
  String _safeImageValue(String? image) {
    final value = image?.trim() ?? '';
    if (value.isEmpty) return '';
    if (value.startsWith('<')) return '';
    return value;
  }
}
