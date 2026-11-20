import '../../models/employee.dart';
import '../../models/payroll.dart';
import '../../models/product.dart';
import '../../services/employee_service.dart';
import '../../services/payroll_service.dart';
import '../../services/product_service.dart';

/// Maosh sahifalari uchun ma'lumot manbalari.
///
/// Alohida shartnoma — sahifalarni bazasiz (namunaviy ma'lumot bilan)
/// chizib, ko'z bilan tekshirish uchun. Ilovada doim
/// [FirebasePayrollSources] ishlatiladi.
abstract interface class PayrollSources {
  Stream<PayrollRates> rates();
  Stream<Map<String, StaffPay>> staff();
  Stream<Map<String, Map<String, WorkTally>>> workDays(DateTime from, DateTime to);
  Stream<List<PayrollPayment>> payments(String month);
  Stream<List<Employee>> employees();
  Stream<List<Product>> products();

  Future<void> saveRates(PayrollRates rates);
  Future<void> saveStaff(String employeeId, StaffPay pay);
  Future<void> addPayment({
    required String employeeId,
    required double amount,
    required PaymentKind kind,
    required String month,
    String note,
    String byName,
  });
  Future<void> deletePayment(String id);
}

class FirebasePayrollSources implements PayrollSources {
  FirebasePayrollSources();

  late final _payroll = PayrollService();

  @override
  Stream<PayrollRates> rates() => _payroll.streamRates();

  @override
  Stream<Map<String, StaffPay>> staff() => _payroll.streamStaff();

  @override
  Stream<Map<String, Map<String, WorkTally>>> workDays(
          DateTime from, DateTime to) =>
      _payroll.streamWorkDays(from, to);

  @override
  Stream<List<PayrollPayment>> payments(String month) =>
      _payroll.streamPayments(month);

  @override
  Stream<List<Employee>> employees() => EmployeeService().streamEmployees();

  @override
  Stream<List<Product>> products() => ProductService().streamProducts();

  @override
  Future<void> saveRates(PayrollRates rates) => _payroll.saveRates(rates);

  @override
  Future<void> saveStaff(String employeeId, StaffPay pay) =>
      _payroll.saveStaff(employeeId, pay);

  @override
  Future<void> addPayment({
    required String employeeId,
    required double amount,
    required PaymentKind kind,
    required String month,
    String note = '',
    String byName = '',
  }) =>
      _payroll.addPayment(
        employeeId: employeeId,
        amount: amount,
        kind: kind,
        month: month,
        note: note,
        byName: byName,
      );

  @override
  Future<void> deletePayment(String id) => _payroll.deletePayment(id);
}
