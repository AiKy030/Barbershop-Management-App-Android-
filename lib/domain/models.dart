/// Plain data classes. No Flutter and no database imports here.
library;

enum StaffType { regular, reliever }

enum AppearanceMode { system, light, dark }

class ShopSettings {
  const ShopSettings({
    required this.shopName,
    required this.staffLabel,
    required this.defaultStaffPercent,
    required this.appearance,
    required this.language,
    required this.pinHash,
    this.lockOnOpen = true,
    required this.lastBackupAt,
    required this.tutorialSeen,
  });

  final String shopName;

  /// What the shop calls its staff, for example "Barber".
  final String staffLabel;

  /// Whole percent of each sale that goes to the staff member.
  final int defaultStaffPercent;
  final AppearanceMode appearance;
  final String language;
  final String? pinHash;

  /// Whether the PIN is also asked when the app opens. Only matters when a
  /// PIN is set. The PIN always protects closed days.
  final bool lockOnOpen;

  /// True when the app should show the PIN screen on opening.
  bool get locksApp => pinHash != null && lockOnOpen;
  final DateTime? lastBackupAt;
  final bool tutorialSeen;

  int get defaultShopPercent => 100 - defaultStaffPercent;
}

class Staff {
  const Staff({
    required this.id,
    required this.name,
    required this.type,
    required this.percentOverride,
    required this.active,
  });

  final String id;
  final String name;
  final StaffType type;

  /// Null means this person uses the shop default.
  final int? percentOverride;
  final bool active;

  int effectivePercent(int defaultPercent) => percentOverride ?? defaultPercent;
}

class Service {
  const Service({
    required this.id,
    required this.name,
    required this.price,
    required this.active,
    required this.sortOrder,
  });

  final String id;
  final String name;

  /// Centavos.
  final int price;
  final bool active;
  final int sortOrder;
}

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.active,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final bool active;
  final int sortOrder;
}
