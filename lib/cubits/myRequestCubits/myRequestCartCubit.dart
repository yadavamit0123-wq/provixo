import 'package:e_demand/app/generalImports.dart';

@immutable
abstract class MyRequestCartState {}

class MyRequestCartInitial extends MyRequestCartState {}

class MyRequestCartInProgress extends MyRequestCartState {
  final String? bidderId;

  MyRequestCartInProgress({this.bidderId});
}

class MyRequestCartSuccess extends MyRequestCartState {
  MyRequestCartSuccess({
    this.bidderId,
    required this.isBidderCart,
    required this.bidderData,
  });

  final String? bidderId;
  final bool isBidderCart;
  final BidProvider bidderData;
}

class MyRequestCartFailure extends MyRequestCartState {
  MyRequestCartFailure({this.bidderId, required this.errorMessage});

  final String errorMessage;
  final String? bidderId;
}

class MyRequestCartCubit extends Cubit<MyRequestCartState> {
  MyRequestCartCubit(this.cartRepository) : super(MyRequestCartInitial());
  MyRequestRepository cartRepository;

  void emitSuccess(final BidProvider bidder) {
    emit(MyRequestCartSuccess(isBidderCart: true, bidderData: bidder));
  }

  String getProviderIDFromCartData() {
    if (state is MyRequestCartSuccess) {
      final BidProvider cartData = (state as MyRequestCartSuccess).bidderData;
      return cartData.providerId.toString();
    }
    return '0';
  }

  String getCartTotalAmount({
    required bool isAtStoreBooked,
    required String isFrom,
  }) {
    if (state is MyRequestCartSuccess && isFrom == 'customJobRequest') {
      final BidProvider cartData = (state as MyRequestCartSuccess).bidderData;

      final double visitingCharge = isAtStoreBooked
          ? 0
          : double.parse(cartData.visitingCharges ?? "0");

      return (double.parse(cartData.finalTotal ?? cartData.counterPrice) +
              visitingCharge)
          .toString();
    }
    return '0';
  }

  String getCartSubTotalAmount({
    required bool isAtStoreBooked,
    required String isFrom,
  }) {
    if (state is MyRequestCartSuccess && isFrom == 'customJobRequest') {
      final BidProvider cartData = (state as MyRequestCartSuccess).bidderData;

      return double.parse(
        cartData.finalTotal ?? cartData.counterPrice,
      ).toString();
    }
    return '0';
  }

  void clearCartCubit() {
    emit(
      MyRequestCartSuccess(
        bidderData: BidProvider.empty(),
        isBidderCart: false,
      ),
    );
  }

  bool checkAtStoreProviderAvailable({required String isFrom}) {
    if (state is MyRequestCartSuccess && isFrom == 'customJobRequest') {
      return (state as MyRequestCartSuccess).bidderData.atStore == "1";
    }
    return false;
  }

  bool checkAtDoorstepProviderAvailable({required String isFrom}) {
    if (state is MyRequestCartSuccess && isFrom == 'customJobRequest') {
      return (state as MyRequestCartSuccess).bidderData.atDoorstep == "1";
    }
    return false;
  }
}
