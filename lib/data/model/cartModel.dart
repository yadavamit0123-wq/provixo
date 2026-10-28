import 'package:e_demand/data/model/serviceModel.dart';

class Cart {
  List<CartDetails>? cartDetails;
  String? carId;
  String? providerName;
  String? translatedProviderName;
  String? isAtDoorstepAvailable;
  String? isAtStoreAvailable;
  String? providerId;
  String? totalQuantity;
  String? subTotal;
  String? taxValue;
  String? overallAmount;
  String? promoCodeDiscountAmount;
  String? appliedPromoCodeName;
  String? isPayLaterAllowed;
  String? isOnlinePaymentAllowed;
  String? visitingCharges;
  String? advanceBookingDays;
  String? companyName;
  String? translatedCompanyName;
  String? subTotalWithoutTax;
  List<Cart>? otherCarts;
  List<Fees>? fees;
  String? totalServiceCount;
  String? totalProviderCount;
  String? totalOverallAmount;
  bool? isProviderVerified;
  String? providerImage;
  String? providerAddress;
  double? providerLatitude;
  double? providerLongitude;
  double? distance;

  Cart({
    this.carId,
    this.cartDetails,
    this.providerName,
    this.translatedProviderName,
    this.providerId,
    this.totalQuantity,
    this.subTotal,
    this.taxValue,
    this.overallAmount,
    this.appliedPromoCodeName,
    this.promoCodeDiscountAmount,
    this.visitingCharges,
    this.advanceBookingDays,
    this.companyName,
    this.translatedCompanyName,
    this.isPayLaterAllowed,
    this.isAtDoorstepAvailable,
    this.isAtStoreAvailable,
    this.isOnlinePaymentAllowed,
    this.subTotalWithoutTax,
    this.otherCarts,
    this.fees,
    this.totalServiceCount,
    this.totalProviderCount,
    this.totalOverallAmount,
    this.isProviderVerified,
    this.providerImage,
  });

  Cart.fromJson(final Map<String, dynamic> json) {
    if (json['items'] != null && json['items'] is List) {
      cartDetails = <CartDetails>[];
      (json['items'] as List).forEach((final v) {
        cartDetails!.add(CartDetails.fromJson(v));
      });
    }
    if (json['fees'] != null && json['fees'] is List) {
      fees = <Fees>[];
      (json['fees'] as List).forEach((final v) {
        if (v is Map<String, dynamic>) {
          fees!.add(Fees.fromJson(v));
        }
      });
    }
    carId = json["cart_id"]?.toString() ?? '';
    providerId = json['provider_id']?.toString() ?? '';
    providerName = json['provider_name']?.toString() ?? '';
    translatedProviderName = providerName;
    companyName = json['company_name']?.toString() ?? '';
    translatedCompanyName = companyName;
    totalQuantity = json['total_quantity']?.toString() ?? '';
    subTotal = json['sub_total']?.toString() ?? '';
    subTotalWithoutTax = json['sub_total_without_tax']?.toString() ?? '';
    taxValue = json['tax_value']?.toString() ?? '0.00';
    overallAmount = json['overall_amount']?.toString() ?? '';
    visitingCharges = json['visiting_charges']?.toString() ?? '';
    advanceBookingDays = json['advance_booking_days']?.toString() ?? '';
    isPayLaterAllowed = json['is_pay_later_allowed']?.toString() ?? '';
    isOnlinePaymentAllowed =
        json['is_online_payment_allowed']?.toString() ?? '';
    isAtStoreAvailable = json['at_store']?.toString() ?? '';
    isAtDoorstepAvailable = json['at_doorstep']?.toString() ?? '';
    isProviderVerified = json['is_provider_verified']?.toString() == "1";
    providerImage = json['provider_image']?.toString() ?? '';
    totalServiceCount = json['total_service_count']?.toString() ?? '';
    totalProviderCount = json['total_provider_count']?.toString() ?? '';
    totalOverallAmount = json['total_overall_amount']?.toString() ?? '';
    providerAddress = json['provider_address']?.toString() ?? '';
    providerLatitude = double.tryParse(
      json['provider_latitude']?.toString() ?? '',
    );
    providerLongitude = double.tryParse(
      json['provider_longitude']?.toString() ?? '',
    );
    distance = double.tryParse(json['distance']?.toString() ?? '');
    if (json['other_carts'] != null && json['other_carts'] is List) {
      otherCarts = <Cart>[];
      (json['other_carts'] as List).forEach((final v) {
        if (v is Map<String, dynamic>) {
          otherCarts!.add(Cart.fromJson(v));
        }
      });
    }
  }
}

class Fees {
  String? id;
  String? title;
  String? valueType;
  String? value;
  String? isRefundable;
  String? amount;

  Fees({
    this.id,
    this.title,
    this.valueType,
    this.value,
    this.isRefundable,
    this.amount,
  });

  Fees.fromJson(final Map<String, dynamic> json) {
    id = json['id']?.toString() ?? '';
    title = json['title']?.toString() ?? '';
    valueType = json['value_type']?.toString() ?? '';
    value = json['value']?.toString() ?? '';
    isRefundable = json['is_refundable']?.toString() ?? '';
    amount = json['amount']?.toString() ?? '';
  }
}

class CartDetails {
  String? id;
  String? serviceId;
  String? qty;
  Services? serviceDetails;

  CartDetails({this.id, this.serviceId, this.qty, this.serviceDetails});

  CartDetails.fromJson(final Map<String, dynamic> json) {
    id = json['id']?.toString() ?? '';
    serviceId = json['service_id']?.toString() ?? '';
    qty = json['qty']?.toString() ?? '';
    serviceDetails = Services.fromJson({
      'id': json['service_id'],
      'title': json['service_title'],
      'translated_title': json['service_title'],
      'price': json['price'],
      'discounted_price': json['discounted_price'],
      'image': json['image_of_the_service'],
      'max_quantity_allowed': json['max_quantity_allowed'],
    });
  }
}
