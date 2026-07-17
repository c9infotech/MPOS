import '../api/api_client.dart';
import '../auth/auth_service.dart';
import '../config/config_loader.dart';
import '../../models/customer.dart';
import '../../models/delivery_note.dart';
import '../../models/payment_mode.dart';
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

    await _auth.saveSession(ui: responseData, database: db);
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

  Future<void> createDeliveryNote({
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
      'U_BookingName': customer.customerName,
      'Reference2': customer.contact,
      'Comments': 'MPOS mobile',
      'SessionId': _session.sessionId,
      'DeliveryNotePostingDetails': details,
    });

    if (data['statusCode'] != 0) {
      throw ApiException(ApiClient.extractError(data));
    }
  }

  Future<List<DeliveryNote>> fetchDeliveryNotes() async {
    final data = await _api.post('DeliveryNoteDetails', {
      'UserCode': _session.userCode,
      'Index': 1,
    });
    final list = data['responseData'];
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(DeliveryNote.fromJson)
        .toList();
  }

  Future<List<PaymentMode>> fetchPaymentModes() async {
    final data = await _api.post('PaymentMode', {});
    final list = data['responseData'];
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(PaymentMode.fromJson)
        .toList();
  }

  Future<void> savePayment({
    required List<DeliveryNote> notes,
    required PaymentMode paymentMode,
    required double amount,
  }) async {
    if (notes.isEmpty) {
      throw ApiException('No sales selected.');
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
      'SalesInvoiceDetails': invoiceDetails,
      'PaymentInvoice': [
        {
          'Branch': paymentMode.branch,
          'PaymentMode': paymentMode.paymentMode,
          'CashSum': amount.toStringAsFixed(2),
        },
      ],
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
}
