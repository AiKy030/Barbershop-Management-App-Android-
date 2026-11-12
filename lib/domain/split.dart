/// Splitting one sale between the staff member and the shop.
library;

class SaleSplit {
  const SaleSplit({required this.staffShare, required this.shopShare});

  /// Centavos, always a whole number of pesos unless capped by the price.
  final int staffShare;

  /// Centavos. Whatever is left after the staff share.
  final int shopShare;
}

/// Splits [price] (centavos) using [staffPercent] (0 to 100).
///
/// The staff share is rounded to the nearest peso, with exactly 50 centavos
/// rounding up. The shop gets the remainder, so the two always add up to the
/// price. The staff share is never more than the price.
SaleSplit splitSale({required int price, required int staffPercent}) {
  if (price < 0) throw ArgumentError.value(price, 'price');
  if (staffPercent < 0 || staffPercent > 100) {
    throw ArgumentError.value(staffPercent, 'staffPercent');
  }
  // price * percent is in units of 1/100 centavo; 10000 of them make a peso.
  final wholePesos = (price * staffPercent + 5000) ~/ 10000;
  var staffShare = wholePesos * 100;
  if (staffShare > price) staffShare = price;
  return SaleSplit(staffShare: staffShare, shopShare: price - staffShare);
}
