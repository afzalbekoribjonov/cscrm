import '../../models/employee.dart';
import '../../models/expense.dart';
import '../../models/order.dart';
import '../../models/order_history_entry.dart';
import '../../services/employee_service.dart';
import '../../services/expense_service.dart';
import '../../services/order_service.dart';

/// Bosh sahifa va xodim faoliyati sahifasi uchun ma'lumot manbalari.
///
/// Alohida shartnoma — sahifalarni bazasiz (namunaviy ma'lumot bilan)
/// chizib, ko'z bilan tekshirish uchun. Ilovada doim
/// [FirebaseDashboardSources] ishlatiladi.
abstract interface class DashboardSources {
  Stream<List<OrderHistoryEntry>> history(DateTime from, DateTime to);
  Stream<List<Order>> delivered(DateTime from, DateTime to);
  Stream<List<Expense>> expenses(DateTime from, DateTime to);
  Stream<List<Order>> debtors();
  Stream<List<Employee>> employees();
}

class FirebaseDashboardSources implements DashboardSources {
  FirebaseDashboardSources();

  late final _orders = OrderService();

  @override
  Stream<List<OrderHistoryEntry>> history(DateTime from, DateTime to) =>
      _orders.streamHistoryBetween(from, to);

  @override
  Stream<List<Order>> delivered(DateTime from, DateTime to) =>
      _orders.streamOrdersDeliveredBetween(from, to);

  @override
  Stream<List<Expense>> expenses(DateTime from, DateTime to) =>
      ExpenseService().streamExpensesBetween(from, to);

  @override
  Stream<List<Order>> debtors() => _orders.streamDebtors();

  @override
  Stream<List<Employee>> employees() => EmployeeService().streamEmployees();
}
