import 'package:flutter/foundation.dart';

import '../../data/repositories.dart';
import '../../domain/models.dart';

/// Holds the shop setup (settings, staff, services, expense categories) for
/// the UI and saves every change through the repositories.
class ShopConfig extends ChangeNotifier {
  ShopConfig({
    required this._settingsRepo,
    required this._staffRepo,
    required this._serviceRepo,
    required this._categoryRepo,
  });

  final SettingsRepository _settingsRepo;
  final StaffRepository _staffRepo;
  final ServiceRepository _serviceRepo;
  final ExpenseCategoryRepository _categoryRepo;

  late ShopSettings settings;
  List<Staff> staff = const [];
  List<Service> services = const [];
  List<ExpenseCategory> categories = const [];

  Future<void> load() async {
    settings = await _settingsRepo.load();
    staff = await _staffRepo.all();
    services = await _serviceRepo.all();
    categories = await _categoryRepo.all();
    notifyListeners();
  }

  Future<void> setShopName(String name) async {
    await _settingsRepo.setShopName(name);
    await load();
  }

  Future<void> setDefaultStaffPercent(int percent) async {
    await _settingsRepo.setDefaultStaffPercent(percent);
    await load();
  }

  Future<void> setAppearance(AppearanceMode mode) async {
    await _settingsRepo.setAppearance(mode);
    await load();
  }

  Future<void> markBackedUp() async {
    await _settingsRepo.setLastBackupAt(DateTime.now());
    await load();
  }

  Future<void> setTutorialSeen() async {
    if (settings.tutorialSeen) return;
    await _settingsRepo.setTutorialSeen(true);
    await load();
  }

  /// Null removes the PIN. [lockOnOpen] says whether the app also asks for
  /// the PIN when it opens.
  Future<void> setPinHash(String? hash, {bool lockOnOpen = true}) async {
    await _settingsRepo.setPinHash(hash, lockOnOpen: lockOnOpen);
    await load();
  }

  Future<void> setLockOnOpen(bool lockOnOpen) async {
    await _settingsRepo.setLockOnOpen(lockOnOpen);
    await load();
  }

  /// Creates a service when [id] is null, otherwise updates it.
  /// [price] is in centavos.
  Future<void> saveService({
    String? id,
    required String name,
    required int price,
  }) async {
    if (id == null) {
      await _serviceRepo.create(name: name, price: price);
    } else {
      await _serviceRepo.update(id, name: name, price: price);
    }
    await load();
  }

  Future<void> setServiceActive(String id, bool active) async {
    await _serviceRepo.setActive(id, active);
    await load();
  }

  Future<void> saveStaff({
    String? id,
    required String name,
    required StaffType type,
    required int? percentOverride,
  }) async {
    if (id == null) {
      await _staffRepo.create(
        name: name,
        type: type,
        percentOverride: percentOverride,
      );
    } else {
      await _staffRepo.update(
        id,
        name: name,
        type: type,
        percentOverride: percentOverride,
      );
    }
    await load();
  }

  Future<void> setStaffActive(String id, bool active) async {
    await _staffRepo.setActive(id, active);
    await load();
  }

  Future<void> saveCategory({String? id, required String name}) async {
    if (id == null) {
      await _categoryRepo.create(name: name);
    } else {
      await _categoryRepo.rename(id, name);
    }
    await load();
  }

  Future<void> setCategoryActive(String id, bool active) async {
    await _categoryRepo.setActive(id, active);
    await load();
  }
}
