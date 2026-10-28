import 'package:e_demand/app/generalImports.dart';
import 'package:e_demand/ui/widgets/bottomsheets/layouts/cartListBottomSheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // ignore_for_file: prefer_typing_uninitialized_variables
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';
import 'package:intl/intl.dart' as intl;

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    required this.companyName,
    required this.providerAdvanceBookingDays,
    required this.providerName,
    required this.providerId,
    final Key? key,
    required this.isFrom,
    this.orderID,
    this.customJobRequestId,
    this.bidder,
    this.cartFromProvider,
    this.cartId,
  }) : super(key: key);

  final String providerName;
  final String isFrom;
  final String providerId;
  final String companyName;
  final String providerAdvanceBookingDays;
  final String? orderID;
  final String? customJobRequestId;
  final BidProvider? bidder;
  final bool? cartFromProvider;
  final String? cartId;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();

  static Route route(final RouteSettings routeSettings) {
    final arguments = routeSettings.arguments as Map;
    return CupertinoPageRoute(
      builder: (final BuildContext context) => Builder(
        builder: (final context) => MultiBlocProvider(
          providers: [
            BlocProvider<PlaceOrderCubit>(
              create: (final BuildContext context) =>
                  PlaceOrderCubit(cartRepository: CartRepository()),
            ),
            BlocProvider(
              create: (context) =>
                  AddTransactionCubit(bookingRepository: BookingRepository()),
            ),
            BlocProvider<ValidateCustomTimeCubit>(
              create: (context) =>
                  ValidateCustomTimeCubit(cartRepository: CartRepository()),
            ),
            BlocProvider<CheckProviderAvailabilityCubit>(
              create: (final BuildContext context) =>
                  CheckProviderAvailabilityCubit(
                    providerRepository: ProviderRepository(),
                  ),
            ),
            BlocProvider<RequestAreaCoverageCubit>(
              create: (final BuildContext context) => RequestAreaCoverageCubit(
                providerRepository: ProviderRepository(),
              ),
            ),
            BlocProvider<ValidatePromocodeCubit>(
              create: (final BuildContext context) =>
                  ValidatePromocodeCubit(cartRepository: CartRepository()),
            ),
          ],
          child: CheckoutScreen(
            orderID: arguments["orderID"],
            customJobRequestId: arguments["customJobRequestId"],
            companyName: arguments["companyName"] ?? '',
            isFrom: arguments["isFrom"] ?? '',
            providerName: arguments['providerName'] ?? '',
            providerId: arguments['providerId'] ?? '',
            providerAdvanceBookingDays:
                arguments['providerAdvanceBookingDays'] ?? '',
            bidder: arguments['bidder'],
            cartFromProvider: arguments['cartFromProvider'] ?? false,
            cartId: arguments['cartId'],
          ),
        ),
      ),
    );
  }
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  ValueNotifier<bool> isPaymentProcessing = ValueNotifier<bool>(false);

  PaymentGatewaysSettings? paymentGatewaySetting;
  String? placedOrderId;
  StreamSubscription? _cartSubscription;
  int? selectedAddressIndex;
  GetAddressModel? selectedAddress;
  String? _lastCheckedProviderAvailabilityKey;
  final ValueNotifier<bool> _isLocationUnavailableAtDoorstep =
      ValueNotifier<bool>(false);
  dynamic selectedDate, selectedTime;
  String? message;
  Promocode? appliedPromocode;
  double promoCodeDiscount = 0;
  bool isBillDetailsExpanded = true;
  late List<Map<String, dynamic>> enabledPaymentMethods = context
      .read<SystemSettingCubit>()
      .getEnabledPaymentMethods(
        isOnlinePaymentAllowed: widget.isFrom != "customJobRequest"
            ? context.read<CartCubit>().isOnlinePaymentAllowed(
                isFrom: widget.isFrom,
              )
            : context.read<SystemSettingCubit>().isOnlinePaymentAllowedGlobally,
        isPayLaterAllowed: widget.isFrom != "customJobRequest"
            ? context.read<CartCubit>().isPayLaterAllowed(isFrom: widget.isFrom)
            : context.read<SystemSettingCubit>().isPayLaterAllowedGlobally,
      );

  ValueNotifier<String> paymentButtonName = ValueNotifier('');

  String? selectedPaymentMethod;
  final TextEditingController _instructionController = TextEditingController();

  final List<Map<String, String>> deliverableOptions = [
    {
      "title": 'atHome',
      "description": 'atHomeDescription',
      "image": AppAssets.homeAdd,
    },
    {
      "title": 'atStore',
      "description": 'atStoreDescription',
      "image": AppAssets.storeOutline,
    },
  ];
  late String selectedDeliverableOption = deliverableOptions[0]['title']!;
  final GlobalKey _deliverablePillKey = GlobalKey();

  //----------------------------------- Razorpay Payment Gateway Start ----------------------------
  final Razorpay _razorpay = Razorpay();

  //----------------------------------- Cashfree Payment Gateway Start ----------------------------
  final CFPaymentGatewayService _cfPaymentGatewayService =
      CFPaymentGatewayService();

  void initializeCashfree() {
    _cfPaymentGatewayService.setCallback(
      _handleCashfreePaymentSuccess,
      _handleCashfreePaymentError,
    );
  }

  Future<void> _handleCashfreePaymentSuccess(String cfOrderId) async {
    final CashfreeOrderStatus status = await CartRepository()
        .getCashfreeOrderStatus(orderId: cfOrderId);
    _navigateToOrderConfirmation(
      isSuccess: status == CashfreeOrderStatus.paid,
      isPending: status == CashfreeOrderStatus.pending,
    );
  }

  void _handleCashfreePaymentError(
    CFErrorResponse errorResponse,
    String cfOrderId,
  ) {
    _navigateToOrderConfirmation(isSuccess: false);
  }

  Future<void> openCashfreePaymentGateway({
    required final double orderAmount,
    required final String localOrderId,
    required final String cashfreePaymentSessionId,
    required final String cashfreeOrderId,
  }) async {
    try {
      ClarityService.logAction(
        ClarityActions.paymentGatewayRedirected,
        _buildCartAnalyticsPayload(
          paymentMethod: 'cashfree',
          paymentAmount: orderAmount.toString(),
        ),
      );
      ClarityService.setTag('payment_gateway', 'cashfree');

      if (cashfreePaymentSessionId.isEmpty) {
        UiUtils.showMessage(
          context,
          'onlinePaymentNotAvailableNow'.translate(context: context),
          ToastificationType.warning,
        );
        return;
      }

      final CFEnvironment cfEnvironment =
          (paymentGatewaySetting?.cashfreeEnvironment ?? '').toLowerCase() ==
              'production'
          ? CFEnvironment.PRODUCTION
          : CFEnvironment.SANDBOX;

      final CFSession session = CFSessionBuilder()
          .setEnvironment(cfEnvironment)
          .setOrderId(
            cashfreeOrderId.isNotEmpty ? cashfreeOrderId : localOrderId,
          )
          .setPaymentSessionId(cashfreePaymentSessionId)
          .build();

      final cfWebCheckout = CFWebCheckoutPaymentBuilder()
          .setSession(session)
          .build();

      _cfPaymentGatewayService.doPayment(cfWebCheckout);
    } on CFException catch (e) {
      UiUtils.showMessage(context, e.message, ToastificationType.error);
      _navigateToOrderConfirmation(isSuccess: false);
    } catch (e) {
      UiUtils.showMessage(
        context,
        'paymentFailure'.translate(context: context),
        ToastificationType.error,
      );
      _navigateToOrderConfirmation(isSuccess: false);
    }
  }

  //----------------------------------- Cashfree Payment Gateway End ----------------------------

  void initializeRazorpay() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleRazorPayPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleRazorPayPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleRazorPayExternalWallet);
  }

  void _handleRazorPayPaymentSuccess(final PaymentSuccessResponse response) {
    _navigateToOrderConfirmation(isSuccess: true);
  }

  void _handleRazorPayPaymentError(final PaymentFailureResponse response) {
    _navigateToOrderConfirmation(isSuccess: false);
  }

  void _handleRazorPayExternalWallet(final ExternalWalletResponse response) {}

  Future<void> openRazorPayGateway({
    required final double orderAmount,
    required final String placedOrderId,
    required final String razorpayOrderId,
  }) async {
    ClarityService.logAction(
      ClarityActions.paymentGatewayRedirected,
      _buildCartAnalyticsPayload(
        paymentMethod: 'razorpay',
        paymentAmount: orderAmount.toString(),
      ),
    );
    ClarityService.setTag('payment_gateway', 'razorpay');
    final options = <String, Object?>{
      'key': paymentGatewaySetting!.razorpayKey,
      //this should be come from server
      'amount': (orderAmount * 100).toInt(),
      'name': appName,
      'description': '',
      'currency': paymentGatewaySetting!.razorpayCurrency,
      'notes': {'order_id': placedOrderId},
      'order_id': razorpayOrderId,
    };

    _razorpay.open(options);
  }

  //----------------------------------- Razorpay Payment Gateway End ----------------------------

  //----------------------------------- Stripe Payment Gateway Start ----------------------------

  Future<void> openStripePaymentGateway({
    required final double orderAmount,
    required final String placedOrderId,
  }) async {
    try {
      //to disable back button
      isPaymentProcessing.value = true;
      ClarityService.logAction(
        ClarityActions.paymentGatewayRedirected,
        _buildCartAnalyticsPayload(
          paymentMethod: 'stripe',
          paymentAmount: orderAmount.toString(),
        ),
      );
      ClarityService.setTag('payment_gateway', 'stripe');
      StripeService.init(
        paymentGatewaySetting!.stripePublishableKey,
        paymentGatewaySetting!.stripeMode,
      );

      final response = await StripeService.payWithPaymentSheet(
        orderId: placedOrderId,
      );
      //to enable back button
      isPaymentProcessing.value = false;

      if (response.status == 'succeeded') {
        _navigateToOrderConfirmation(isSuccess: true);
      } else {
        _navigateToOrderConfirmation(isSuccess: false);
      }
    } catch (e) {
      isPaymentProcessing.value = false;
      UiUtils.showMessage(context, e.toString(), ToastificationType.error);
    }
  }

  //----------------------------------- Stripe Payment Gateway End ----------------------------

  void _navigateToOrderConfirmation({
    required final bool isSuccess,
    final bool isPending = false,
  }) {
    if (!isSuccess) {
      final payload = _buildCartAnalyticsPayload(
        paymentMethod: selectedPaymentMethod,
        paymentAmount: _currentCartTotalAmount(),
      );
      payload['result'] = isPending ? 'pending' : 'failure';
      ClarityService.logAction(
        isPending
            ? ClarityActions.paymentPending
            : ClarityActions.paymentFailed,
        payload,
      );
      paymentButtonName.value = "rePayment";
      context.read<AddTransactionCubit>().addTransaction(
        status: isPending ? "pending" : "cancelled",
        orderID: placedOrderId ?? "0",
      );
      context.read<BookingCubit>().fetchAllBookings(status: '');
      Navigator.pushNamed(
        context,
        orderConfirmation,
        arguments: {
          'isSuccess': false,
          'isPending': isPending,
          "orderId": placedOrderId,
          "isReBooking": widget.isFrom == "reBooking" ? '1' : '0',
          if (widget.isFrom == "customJobRequest")
            "customJobRequestId": widget.customJobRequestId,
        },
      );
      return;
    }
    final payload = _buildCartAnalyticsPayload(
      paymentMethod: selectedPaymentMethod,
      paymentAmount: _currentCartTotalAmount(),
    );
    payload['result'] = 'success';
    ClarityService.logAction(ClarityActions.paymentSucceeded, payload);
    Navigator.pushNamed(
      context,
      orderConfirmation,
      arguments: {
        'isSuccess': isSuccess,
        "orderId": placedOrderId,
        "isReBooking": widget.isFrom == "reBooking" ? '1' : '0',
        if (widget.isFrom == "customJobRequest")
          "customJobRequestId": widget.customJobRequestId,
      },
    );
  }

  void getPaymentGatewaySetting() {
    paymentGatewaySetting = context
        .read<SystemSettingCubit>()
        .paymentGatewaysSettings;

    if (widget.isFrom != "customJobRequest" &&
        context.read<CartCubit>().isOnlinePaymentAllowed(
          isFrom: widget.isFrom,
        )) {
      paymentButtonName = ValueNotifier("makePayment");
    } else if (widget.isFrom == "customJobRequest" &&
        context.read<SystemSettingCubit>().isOnlinePaymentAllowedGlobally) {
      paymentButtonName = ValueNotifier("makePayment");
    } else {
      paymentButtonName = ValueNotifier("bookService");
    }
  }

  void getMyRequests() {
    if (widget.isFrom == "customJobRequest") {
      final MyRequestCartCubit myRequestCartCubit = context
          .read<MyRequestCartCubit>();
      myRequestCartCubit.emitSuccess(widget.bidder ?? BidProvider.empty());
      _syncSelectedDeliverableOption(
        atStoreAvailable: myRequestCartCubit.checkAtStoreProviderAvailable(
          isFrom: widget.isFrom,
        ),
        atDoorstepAvailable: myRequestCartCubit
            .checkAtDoorstepProviderAvailable(isFrom: widget.isFrom),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    getMyRequests();
    context.read<GetAddressCubit>().fetchAddress();
    getPaymentGatewaySetting();
    initializeRazorpay();
    initializeCashfree();
    if (widget.isFrom != "customJobRequest") {
      final CartCubit cartCubit = context.read<CartCubit>();
      final bool isReorderCart = widget.isFrom == "reBooking";
      final bool cartAlreadyLoaded =
          !isReorderCart &&
          cartCubit.state is CartFetchSuccess &&
          ((cartCubit.state as CartFetchSuccess).cartData.carId?.isNotEmpty ??
              false);

      final bool selectedLocally =
          cartAlreadyLoaded &&
          (widget.isFrom != "cart" ||
              widget.cartId == null ||
              cartCubit.selectPrimaryCart(widget.cartId!));

      if (!selectedLocally) {
        cartCubit.getCartDetails(
          isReorderCart: isReorderCart,
          reOrderId: widget.orderID,
          preferredCartId: widget.isFrom == "cart" ? widget.cartId : null,
        );
      } else if (cartCubit.state is CartFetchSuccess) {
        _syncSelectedDeliverableOption(
          atStoreAvailable: cartCubit.checkAtStoreProviderAvailable(
            isFrom: widget.isFrom,
          ),
          atDoorstepAvailable: cartCubit.checkAtDoorstepProviderAvailable(
            isFrom: widget.isFrom,
          ),
        );
      }
    }
    if (widget.isFrom == "customJobRequest") {
      getMyRequests();
    }
    if (widget.isFrom != "customJobRequest" && widget.providerId != "0") {
      context.read<GetAllPromocodesCubit>().getAllPromocodes(
        providerIdOrSlug: widget.providerId,
      );
    }

    if (widget.isFrom != "customJobRequest" &&
        context.read<CartCubit>().isOnlinePaymentAllowed(
          isFrom: widget.isFrom,
        )) {
      selectedPaymentMethod = enabledPaymentMethods[0]['paymentType'];
    } else if (widget.isFrom == "customJobRequest" &&
        context.read<SystemSettingCubit>().isOnlinePaymentAllowedGlobally) {
      selectedPaymentMethod = enabledPaymentMethods[0]['paymentType'];
    } else {
      selectedPaymentMethod = "cod";
    }

    //listning to the state changes of place order cubit to disable the back button
    context.read<PlaceOrderCubit>().stream.listen((state) {
      isPaymentProcessing.value = state is PlaceOrderInProgress;
    });
  }

  Widget getHeadingTimeSelector() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: CustomText(
      'scheduleTime'.translate(context: context),
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: context.colors.textPrimary,
    ),
  );

  Widget verticalSpacing() {
    return const CustomSizedBox(height: 10);
  }

  Map<String, Object?> _buildCartAnalyticsPayload({
    String? paymentMethod,
    String? paymentAmount,
  }) {
    final Map<String, Object?> data = {
      'source': widget.isFrom,
      'provider_id': widget.providerId,
      'provider_name': widget.providerName,
      'company_name': widget.companyName,
      'delivery_type': selectedDeliverableOption,
      'selected_date': selectedDate ?? '',
      'selected_time': selectedTime ?? '',
      'custom_job_request_id': widget.customJobRequestId ?? '',
      'payment_method': paymentMethod,
      'payment_amount': paymentAmount,
      'promo_code_name': appliedPromocode?.promoCode ?? '',
    };

    if (widget.isFrom == 'customJobRequest') {
      final myRequestState = context.read<MyRequestCartCubit>().state;
      if (myRequestState is MyRequestCartSuccess) {
        final bidder = myRequestState.bidderData;
        data.addAll({
          'partner_id': bidder.providerId.toString(),
          'partner_name': bidder.translatedProviderName ?? bidder.companyName,
          'bidder_price': bidder.counterPrice,
          'final_total': bidder.finalTotal ?? bidder.counterPrice,
        });
      }
    } else {
      final cartState = context.read<CartCubit>().state;
      if (cartState is CartFetchSuccess) {
        final cart = cartState.cartData;
        final serviceNames =
            cart.cartDetails
                ?.map(
                  (detail) =>
                      detail.serviceDetails?.translatedTitle ??
                      detail.serviceDetails?.title ??
                      '',
                )
                .where((name) => name.isNotEmpty)
                .toList() ??
            <String>[];
        data.addAll({
          'cart_provider_id': cart.providerId ?? '',
          'cart_provider_name':
              cart.translatedProviderName ?? cart.providerName ?? '',
          'services': serviceNames.join('|'),
          'service_count': serviceNames.length,
          'total_quantity': cart.totalQuantity ?? '',
          'subtotal': cart.subTotal ?? '',
          'overall_amount': cart.overallAmount ?? '',
          'promo_code_name':
              cart.appliedPromoCodeName ?? appliedPromocode?.promoCode ?? '',
          'promo_discount': cart.promoCodeDiscountAmount ?? '',
        });
      }
    }

    data.removeWhere(
      (key, value) =>
          value == null ||
          (value is String && value.isEmpty) ||
          (value is num && value == 0),
    );
    return data;
  }

  String _currentCartTotalAmount() {
    final bool isAtStore = selectedDeliverableOption == "atStore";
    if (widget.isFrom == 'customJobRequest') {
      return context.read<MyRequestCartCubit>().getCartTotalAmount(
        isAtStoreBooked: isAtStore,
        isFrom: widget.isFrom,
      );
    }
    return context.read<CartCubit>().getCartTotalAmount(
      isAtStoreBooked: isAtStore,
      isFrom: widget.isFrom,
    );
  }

  Widget _buildViewProviderInstructionField({final bool fullWidth = false}) =>
      CustomContainer(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: fullWidth
            ? context.colors.backgroundPrimary
            : context.colors.backgroundSecondary,
        border: fullWidth
            ? null
            : Border.all(color: context.colors.borderDefault),
        borderRadius: 12,
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            CustomSvgPicture(
              svgImage: AppAssets.edit,
              color: context.colors.iconPrimary,
              height: 16,
              width: 16,
            ),
            const CustomSizedBox(width: 8),
            CustomText(
              'writeInstruction'.translate(context: context),
              color: context.colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.normal,
            ),
          ],
        ),
      );

  Widget _buildFilledProviderInstructionField(final String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomText(
                'providerInstruction'.translate(context: context),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: context.colors.textSecondary,
              ),
              const CustomSizedBox(height: 4),
              CustomText(
                text,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: context.colors.textPrimary,
              ),
            ],
          ),
        ),
        const CustomSizedBox(width: 8),
        CustomInkWellContainer(
          borderRadius: BorderRadius.circular(24),
          onTap: _openProviderInstructionBottomSheet,
          child: CustomContainer(
            padding: const EdgeInsets.all(8),
            color: context.colors.backgroundSecondary,
            borderRadius: 24,
            child: CustomSvgPicture(
              svgImage: AppAssets.edit,
              color: context.colors.iconPrimary,
              height: 20,
              width: 20,
            ),
          ),
        ),
      ],
    ),
  );

  void _openProviderInstructionBottomSheet() {
    UiUtils.showBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
      child: ProviderInstructionBottomSheet(
        initialInstruction: _instructionController.text,
      ),
    ).then((final Object? value) {
      if (value is String) {
        _instructionController.text = value;
      }
    });
  }

  void _checkProviderAvailabilityForSelectedAddress() {
    if (selectedAddress == null ||
        selectedDeliverableOption != deliverableOptions[0]["title"]) {
      return;
    }

    final bool isCartDataReady = widget.isFrom == "customJobRequest"
        ? context.read<MyRequestCartCubit>().state is MyRequestCartSuccess
        : context.read<CartCubit>().state is CartFetchSuccess;
    if (!isCartDataReady) return;

    final String key = '${selectedAddress!.id}|$selectedDeliverableOption';
    if (_lastCheckedProviderAvailabilityKey == key) return;
    _lastCheckedProviderAvailabilityKey = key;

    WidgetsBinding.instance.addPostFrameCallback((final _) {
      if (!mounted) return;

      final String latitude = selectedAddress?.lattitude.toString() ?? '';
      final String longitude = selectedAddress?.longitude.toString() ?? '';

      if (context.read<MyRequestCartCubit>().checkAtDoorstepProviderAvailable(
        isFrom: widget.isFrom,
      )) {
        context
            .read<CheckProviderAvailabilityCubit>()
            .checkProviderAvailability(
              customJobRequestId: widget.bidder?.customJobRequestId,
              bidderId: widget.bidder?.providerId.toString(),
              isAuthTokenRequired: true,
              checkingAtCheckOut: '1',
              latitude: latitude,
              longitude: longitude,
            );
      } else if (widget.isFrom != "customJobRequest" &&
          context.read<CartCubit>().checkAtDoorstepProviderAvailable(
            isFrom: widget.isFrom,
          )) {
        context
            .read<CheckProviderAvailabilityCubit>()
            .checkProviderAvailability(
              orderId: widget.orderID,
              isAuthTokenRequired: true,
              checkingAtCheckOut: '1',
              latitude: latitude,
              longitude: longitude,
            );
      }
    });
  }

  Widget buildServiceLocationValue({
    required final String value,
    required final VoidCallback onTap,
  }) => CustomInkWellContainer(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomText(
          'serviceLocation'.translate(context: context),
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: context.colors.textSecondary,
        ),
        const CustomSizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: CustomText(
                value,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                maxLines: 1,
                color: context.colors.textPrimary,
              ),
            ),
            const CustomSizedBox(width: 4),
            CustomSvgPicture(
              svgImage: AppAssets.downArrow,
              height: 16,
              width: 16,
              color: context.colors.iconPrimary,
            ),
          ],
        ),
      ],
    ),
  );

  Widget buildAddressSelector() {
    return BlocListener<AddAddressCubit, AddAddressState>(
      listener:
          (final BuildContext context, final AddAddressState addAddressState) {
            if (addAddressState is AddAddressFail) {
              UiUtils.showMessage(
                context,
                addAddressState.error.toString(),
                ToastificationType.error,
              );
            }
          },
      child: BlocConsumer<GetAddressCubit, GetAddressState>(
        listener:
            (
              final BuildContext context,
              final GetAddressState getAddressState,
            ) {
              if (getAddressState is GetAddressSuccess) {
                for (var i = 0; i < getAddressState.data.length; i++) {
                  //we will make default address as selected address
                  //so we will take index of selected address and address data
                  if (getAddressState.data[i].isDefault == "1") {
                    selectedAddressIndex = i;
                    selectedAddress = getAddressState.data[i];
                    setState(() {});
                  }
                }
                context.read<AddressesCubit>().load(getAddressState.data);
              }
            },
        builder:
            (
              final BuildContext context,
              final GetAddressState getAddressState,
            ) {
              if (getAddressState is GetAddressSuccess) {
                if (getAddressState.data.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomText(
                        'noServiceAddressAdded'.translate(context: context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textPrimary,
                      ),
                      const CustomSizedBox(height: 4),
                      CustomInkWellContainer(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            googleMapRoute,
                            arguments: {
                              "defaultLatitude": HiveRepository.getLatitude,
                              "defaultLongitude": HiveRepository.getLongitude,
                              'showAddressForm': true,
                              'screenType':
                                  GoogleMapScreenType.selectLocationOnMap,
                            },
                          ).then((final Object? value) {
                            context.read<GetAddressCubit>().fetchAddress();
                            setState(() {});
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CustomSvgPicture(
                              svgImage: AppAssets.plus,
                              height: 16,
                              width: 16,
                              color: context.colors.iconBrand,
                            ),
                            const CustomSizedBox(width: 4),
                            CustomText(
                              'addAddress'.translate(context: context),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: context.colors.textBrand,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  if (selectedAddress == null) {
                    selectedAddress = getAddressState.data.firstWhere(
                      (e) => e.isDefault == '1',
                      orElse: () => getAddressState.data.first,
                    );
                  }
                  _checkProviderAvailabilityForSelectedAddress();

                  return BlocListener<AddAddressCubit, AddAddressState>(
                    listener: (context, state) {},
                    child: buildServiceLocationValue(
                      value: selectedAddress?.address?.toString() ?? '',
                      onTap: () {
                        UiUtils.showBottomSheet(
                          enableDrag: true,
                          isScrollControlled: true,
                          useSafeArea: true,
                          child: AddressBottomSheet(
                            addresses: getAddressState.data,
                            defaultAddress: selectedAddress!,
                          ),
                          context: context,
                        ).then((final value) {
                          if (value != null &&
                              value['selectedAddress'] != null) {
                            selectedAddress = value['selectedAddress'];
                            context
                                .read<CheckProviderAvailabilityCubit>()
                                .reset();
                            _isLocationUnavailableAtDoorstep.value = false;
                            _checkProviderAvailabilityForSelectedAddress();
                            setState(() {});
                          }
                        });
                      },
                    ),
                  );
                }
              }
              if (getAddressState is GetAddressInProgress) {
                return const CustomShimmerLoadingContainer(
                  height: 36,
                  width: double.infinity,
                );
              }
              return const CustomSizedBox();
            },
      ),
    );
  }

  Widget _deliverableOptionRow(final int index) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CustomSvgPicture(
        svgImage: deliverableOptions[index]['image']!,
        height: 20,
        width: 20,
        color: selectedDeliverableOption == deliverableOptions[index]['title']
            ? context.colors.iconPrimary
            : context.colors.iconSecondary,
      ),
      const CustomSizedBox(width: 8),
      CustomText(
        deliverableOptions[index]['title']!.translate(context: context),
        fontSize: 14,
        color: selectedDeliverableOption == deliverableOptions[index]['title']
            ? context.colors.textPrimary
            : context.colors.textSecondary,
      ),
      if (selectedDeliverableOption == deliverableOptions[index]['title']) ...[
        const CustomSizedBox(width: 12),
        CustomSvgPicture(
          svgImage: AppAssets.checkCircleFill,
          height: 20,
          width: 20,
          color: context.colors.iconBrand,
        ),
      ],
    ],
  );

  void _showDeliverableOptionsMenu() {
    UiUtils.removeFocus();
    final RenderBox? button =
        _deliverablePillKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    if (button == null) {
      return;
    }
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(
          Offset(0, button.size.height + 8),
          ancestor: overlay,
        ),
        button.localToGlobal(
          button.size.bottomRight(const Offset(0, 8)),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: context.colors.surfacePrimary,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      constraints: const BoxConstraints(minWidth: 162),
      items: [
        for (int i = 0; i < deliverableOptions.length; i++) ...[
          if (i > 0)
            PopupMenuItem<String>(
              enabled: false,
              height: 1,
              padding: EdgeInsets.zero,
              child: Container(height: 1, color: context.colors.borderDefault),
            ),
          PopupMenuItem<String>(
            value: deliverableOptions[i]['title'],
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: _deliverableOptionRow(i),
            ),
          ),
        ],
      ],
    ).then((final String? value) {
      if (value != null) {
        selectedDeliverableOption = value;
        _checkProviderAvailabilityForSelectedAddress();
        setState(() {});
      }
    });
  }

  Widget buildDeliverableOptionPill() => CustomInkWellContainer(
    borderRadius: BorderRadius.circular(8),
    onTap: _showDeliverableOptionsMenu,
    child: CustomContainer(
      key: _deliverablePillKey,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: context.colors.backgroundSecondary,
      border: Border.all(color: context.colors.borderDefault),
      borderRadius: 8,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomText(
            selectedDeliverableOption.translate(context: context),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: context.colors.textPrimary,
          ),
          const CustomSizedBox(width: 6),
          CustomSvgPicture(
            svgImage: AppAssets.downArrow,
            height: 14,
            width: 14,
            color: context.colors.iconPrimary,
          ),
        ],
      ),
    ),
  );

  Widget buildServiceLocationSection({
    required final bool showAddress,
    required final bool showDeliverableOptions,
    final String? providerAddress,
    final double? providerLatitude,
    final double? providerLongitude,
  }) {
    if (!showAddress && !showDeliverableOptions) {
      return const CustomSizedBox();
    }
    final bool canOpenProviderLocation =
        providerLatitude != null && providerLongitude != null;
    void openProviderLocationSheet() {
      if (!canOpenProviderLocation) return;
      UiUtils.showBottomSheet(
        context: context,
        enableDrag: true,
        isScrollControlled: true,
        useSafeArea: true,
        child: ProviderLocationBottomSheet(
          providerAddress: providerAddress ?? '',
          providerLatitude: providerLatitude,
          providerLongitude: providerLongitude,
        ),
      );
    }

    return CustomContainer(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: context.colors.surfacePrimary,
      border: Border(
        top: BorderSide(color: context.colors.borderDefault, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: showAddress
                ? buildAddressSelector()
                : CustomInkWellContainer(
                    onTap: canOpenProviderLocation
                        ? openProviderLocationSheet
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomText(
                          'providerLocation'.translate(context: context),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: context.colors.textSecondary,
                        ),
                        const CustomSizedBox(height: 4),
                        CustomText(
                          (providerAddress ?? '').isNotEmpty
                              ? providerAddress!
                              : 'atStore'.translate(context: context),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          maxLines: 1,
                          color: context.colors.textPrimary,
                        ),
                      ],
                    ),
                  ),
          ),
          if (showDeliverableOptions) ...[
            const CustomSizedBox(width: 12),
            buildDeliverableOptionPill(),
          ],
        ],
      ),
    );
  }

  Widget buildAddMoreAndInstructionPills(final String? providerId) => Row(
    children: [
      if (widget.isFrom == "cart") ...[
        CustomInkWellContainer(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (widget.cartFromProvider == true) {
              Navigator.pop(context);
            } else {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                providerRoute,
                arguments: {"providerId": providerId},
              );
            }
          },
          child: CustomContainer(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: context.colors.backgroundSecondary,
            border: Border.all(color: context.colors.borderDefault),
            borderRadius: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomSvgPicture(
                  svgImage: AppAssets.plus,
                  height: 16,
                  width: 16,
                  color: context.colors.iconPrimary,
                ),
                const CustomSizedBox(width: 8),
                CustomText(
                  'addMoreItem'.translate(context: context),
                  color: context.colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ],
            ),
          ),
        ),
        const CustomSizedBox(width: 8),
      ],
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _instructionController,
        builder: (context, value, child) => value.text.trim().isNotEmpty
            ? const CustomSizedBox()
            : GestureDetector(
                onTap: _openProviderInstructionBottomSheet,
                child: _buildViewProviderInstructionField(),
              ),
      ),
    ],
  );

  Widget buildServicesList() => BlocBuilder<CartCubit, CartState>(
    builder: (final BuildContext context, final CartState state) {
      if (state is CartFetchSuccess) {
        if (state.cartData.cartDetails == null &&
            state.reOrderCartData?.cartDetails == null) {
          return const CustomSizedBox();
        }
        final List<CartDetails> source = widget.isFrom == "cart"
            ? state.cartData.cartDetails ?? const []
            : widget.isFrom == "customJobRequest"
            ? const []
            : state.reOrderCartData?.cartDetails ?? const [];

        // The cart API can return a service split across more than one
        // row (e.g. added in separate requests) — merge by serviceId so
        // the UI shows one row per service with the true total quantity,
        // instead of duplicate rows that each look like "1x".
        final List<CartDetails> rows = [];
        final Map<String, int> qtyByServiceId = {};
        for (final detail in source) {
          final String? id = detail.serviceId;
          final int qty = int.tryParse(detail.qty ?? '0') ?? 0;
          if (id != null && id.isNotEmpty) {
            if (qtyByServiceId.containsKey(id)) {
              qtyByServiceId[id] = qtyByServiceId[id]! + qty;
              continue;
            }
            qtyByServiceId[id] = qty;
          }
          rows.add(detail);
        }
        final int itemCount = rows.length;
        return CustomContainer(
          padding: const EdgeInsets.all(12),
          color: context.colors.surfacePrimary,
          borderRadius: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: itemCount,
                separatorBuilder: (final context, final index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    height: 1,
                    color: context.colors.borderDefault,
                  ),
                ),
                itemBuilder: (final context, index) {
                  final CartDetails cartDetails = rows[index];
                  final int mergedQty =
                      qtyByServiceId[cartDetails.serviceId] ??
                      int.tryParse(cartDetails.qty ?? '0') ??
                      0;
                  final String? discountedPrice =
                      cartDetails.serviceDetails?.discountedPrice;
                  final bool hasDiscount =
                      discountedPrice != null &&
                      discountedPrice.isNotEmpty &&
                      discountedPrice != '0' &&
                      discountedPrice != '0.0' &&
                      discountedPrice != '0.00';
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CustomImageContainer(
                        borderRadius: 8.8,
                        imageURL:
                            cartDetails.serviceDetails?.imageOfTheService ?? '',
                        height: 44,
                        width: 44,
                        boxFit: BoxFit.cover,
                        boxShadow: const [],
                      ),
                      const CustomSizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CustomText(
                              cartDetails.serviceDetails?.translatedTitle ?? '',
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              maxLines: 2,
                              color: context.colors.textPrimary,
                            ),
                            const CustomSizedBox(height: 4),
                            CustomText(
                              (hasDiscount
                                      ? discountedPrice
                                      : cartDetails.serviceDetails?.price ??
                                            '0')
                                  .priceFormat(context),
                              fontWeight: FontWeight.w400,
                              fontSize: 12,
                              color: context.colors.textPrimary,
                            ),
                          ],
                        ),
                      ),
                      const CustomSizedBox(width: 10),
                      if (widget.isFrom == "cart" &&
                          (cartDetails.serviceId?.isNotEmpty ?? false))
                        MultiBlocProvider(
                          // Scoped per row — a single shared cubit instance
                          // (as provided at the screen level) would make the
                          // in-progress shimmer show on every service row
                          // whenever any one of them was being mutated.
                          providers: [
                            BlocProvider<AddServiceIntoCartCubit>(
                              create: (final BuildContext context) =>
                                  AddServiceIntoCartCubit(CartRepository()),
                            ),
                            BlocProvider<RemoveServiceFromCartCubit>(
                              create: (final BuildContext context) =>
                                  RemoveServiceFromCartCubit(CartRepository()),
                            ),
                          ],
                          child: AddButton(
                            serviceId: cartDetails.serviceId!,
                            providerId: state.cartData.providerId ?? '',
                            serviceProviderName:
                                state.cartData.translatedProviderName ??
                                state.cartData.providerName,
                            alreadyAddedQuantity: mergedQty,
                            maximumAllowedQuantity:
                                int.tryParse(
                                  cartDetails
                                          .serviceDetails
                                          ?.maxQuantityAllowed ??
                                      '10',
                                ) ??
                                10,
                            backgroundColor:
                                context.colors.backgroundBrandSubtle,
                            height: 32,
                            padding: 8,
                            iconSize: 16,
                            countFontSize: 16,
                          ),
                        )
                      else
                        CustomContainer(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          color: context.colors.backgroundBrandSubtle,
                          border: Border.all(color: context.colors.borderBrand),
                          borderRadius: 8,
                          child: CustomText(
                            '${mergedQty}x',
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: context.colors.textBrand,
                          ),
                        ),
                    ],
                  );
                },
              ),
              const CustomSizedBox(height: 12),
              buildAddMoreAndInstructionPills(state.cartData.providerId),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _instructionController,
                builder: (context, value, child) => value.text.trim().isEmpty
                    ? const CustomSizedBox()
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildFilledProviderInstructionField(value.text),
                      ),
              ),
            ],
          ),
        );
      }
      return const CustomSizedBox();
    },
  );

  Widget buildDateSelector() {
    final bool hasDateTimeSelection =
        selectedDate != null && selectedTime != null;
    void onDateSelectorTap() {
      UiUtils.removeFocus();
      final cartState = context.read<CartCubit>().state;
      final String advanceDays =
          (widget.isFrom == "cart" && cartState is CartFetchSuccess)
          ? ((cartState.cartData.advanceBookingDays?.isNotEmpty ?? false)
                ? cartState.cartData.advanceBookingDays!
                : widget.providerAdvanceBookingDays)
          : widget.providerAdvanceBookingDays;
      final String currentProviderId =
          (widget.isFrom == "cart" && cartState is CartFetchSuccess)
          ? ((cartState.cartData.providerId?.isNotEmpty ?? false)
                ? cartState.cartData.providerId!
                : widget.providerId)
          : widget.providerId;

      UiUtils.showBottomSheet(
        enableDrag: true,
        context: context,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ValidateCustomTimeCubit>(
              create: (context) =>
                  ValidateCustomTimeCubit(cartRepository: CartRepository()),
            ),
            BlocProvider(
              create: (final BuildContext context) =>
                  TimeSlotCubit(CartRepository()),
            ),
          ],
          child: CalenderBottomSheet(
            orderId: widget.orderID,
            customJobRequestId: widget.customJobRequestId,
            advanceBookingDays: advanceDays,
            providerId: currentProviderId,
            selectedDate: selectedDate == null
                ? null
                : DateTime.parse(selectedDate),
            selectedTime: selectedTime,
          ),
        ),
      ).then((final value) {
        if (value != null) {
          if (value["isSaved"]) {
            selectedDate = intl.DateFormat(
              'yyyy-MM-dd',
            ).format(DateTime.parse("${value['selectedDate']}"));
            selectedTime = value["selectedTime"];
            message = value["message"];
            setState(() {});
          }
        }
      });
    }

    return CustomContainer(
      padding: const EdgeInsets.all(12),
      color: context.colors.surfacePrimary,
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomContainer(
                padding: const EdgeInsets.all(8),
                color: context.colors.backgroundSecondary,
                borderRadius: 12,
                child: CustomSvgPicture(
                  svgImage: AppAssets.calendar,
                  height: 16,
                  width: 16,
                  color: context.colors.iconPrimary,
                ),
              ),
              const CustomSizedBox(width: 8),
              Expanded(
                child: CustomText(
                  'selectDateAndTime'.translate(context: context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  maxLines: 1,
                  color: context.colors.textPrimary,
                ),
              ),
              CustomInkWellContainer(
                borderRadius: BorderRadius.circular(12),
                onTap: onDateSelectorTap,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomText(
                        'viewAll'.translate(context: context),
                        fontSize: 14,
                        color: context.colors.textBrand,
                      ),
                      const CustomSizedBox(width: 4),
                      CustomSvgPicture(
                        svgImage:
                            Directionality.of(context) == TextDirection.rtl
                            ? AppAssets.backArrow
                            : AppAssets.backArrowLtr,
                        height: 20,
                        width: 20,
                        color: context.colors.iconBrand,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const CustomSizedBox(height: 12),
          Divider(height: 1, color: context.colors.borderDefault),
          const CustomSizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: CustomContainer(
              padding: const EdgeInsets.all(8),
              color: context.colors.backgroundSecondary,
              border: Border.all(color: context.colors.borderDefault),
              borderRadius: 8,
              child: CustomText(
                hasDateTimeSelection
                    ? '${selectedDate.toString().formatDate()}, ${selectedTime.toString().formatTime()}'
                    : 'dateTimePlaceholder'.translate(context: context),
                fontSize: 12,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          if (hasDateTimeSelection && message != null && message != '') ...[
            const CustomSizedBox(height: 4),
            CustomText(
              'orderWillBeScheduledForTheMultipleDays'.translate(
                context: context,
              ),
              fontSize: 11,
              color: context.colors.textBrand,
            ),
          ],
        ],
      ),
    );
  }

  String _promoDiscountLabel(final Promocode promo) {
    final String currency = context.read<SystemSettingCubit>().systemCurrency;
    return '${promo.discount ?? ''}'
        '${promo.discountType == "percentage" ? '%' : ' $currency'} '
        '${'off'.translate(context: context)}';
  }

  String _promoMinOrderLabel(final Promocode promo) =>
      "${'onMinimumServiceOf'.translate(context: context)} "
      "${(promo.minimumOrderAmount ?? '0').priceFormat(context)}";

  Widget _buildOfferRow({
    required final String discountLabel,
    required final String subtitleLabel,
    required final String buttonLabel,
    required final Color buttonColor,
    required final VoidCallback? onButtonTap,
    final bool isLoading = false,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const CustomSvgPicture(
        svgImage: AppAssets.verified,
        height: 24,
        width: 24,
        avoideResponsive: true,
      ),
      const CustomSizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomText(
              discountLabel,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.colors.textPrimary,
            ),
            CustomText(
              subtitleLabel,
              fontSize: 12,
              color: context.colors.textTertiary,
            ),
          ],
        ),
      ),
      const CustomSizedBox(width: 8),
      CustomInkWellContainer(
        borderRadius: BorderRadius.circular(UiUtils.borderRadiusOf12),
        onTap: onButtonTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: isLoading
              ? CustomSizedBox(
                  height: 16,
                  width: 16,
                  child: CustomCircularProgressIndicator(color: buttonColor),
                )
              : CustomText(buttonLabel, fontSize: 14, color: buttonColor),
        ),
      ),
    ],
  );

  Widget _buildSuggestedPromoRow() =>
      BlocBuilder<GetAllPromocodesCubit, GetAllPromocodesState>(
        builder:
            (
              final BuildContext context,
              final GetAllPromocodesState promoState,
            ) {
              final Promocode? suggested =
                  promoState is GetAllPromocodesFetchSuccess &&
                      promoState.promocodeList.isNotEmpty
                  ? promoState.promocodeList.first
                  : null;

              if (suggested == null) {
                return CustomText(
                  "applyCouponAndGetExtraDiscount".translate(context: context),
                  fontSize: 12,
                  color: context.colors.textSecondary,
                );
              }

              return BlocConsumer<
                ValidatePromocodeCubit,
                ValidatePromoCodeState
              >(
                listener:
                    (
                      final BuildContext context,
                      final ValidatePromoCodeState validateState,
                    ) {
                      if (validateState is ValidatePromoCodeSuccess &&
                          validateState.promoCodeId == suggested.id) {
                        if (!validateState.error) {
                          promoCodeDiscount =
                              double.tryParse(validateState.discountAmount) ??
                              0;
                          appliedPromocode = suggested;
                          setState(() {});
                        } else {
                          UiUtils.showMessage(
                            context,
                            validateState.message,
                            ToastificationType.error,
                          );
                        }
                      } else if (validateState is ValidatePromoCodeFailure) {
                        UiUtils.showMessage(
                          context,
                          validateState.errorMessage,
                          ToastificationType.error,
                        );
                      }
                    },
                builder:
                    (
                      final BuildContext context,
                      final ValidatePromoCodeState validateState,
                    ) {
                      final bool isApplying =
                          validateState is ValidatePromoCodeInProgress &&
                          validateState.promoCodeID == suggested.id;
                      return _buildOfferRow(
                        discountLabel: _promoDiscountLabel(suggested),
                        subtitleLabel: _promoMinOrderLabel(suggested),
                        buttonLabel: 'apply'.translate(context: context),
                        buttonColor: context.colors.textBrand,
                        isLoading: isApplying,
                        onButtonTap: isApplying
                            ? null
                            : () {
                                context
                                    .read<ValidatePromocodeCubit>()
                                    .validatePromoCodes(
                                      totalAmount: context
                                          .read<CartCubit>()
                                          .getCartSubTotalAmount(
                                            isFrom: widget.isFrom,
                                            isAtStoreBooked:
                                                selectedDeliverableOption ==
                                                "atStore",
                                          ),
                                      promoCodeID: suggested.id!,
                                    );
                              },
                      );
                    },
              );
            },
      );

  BoxDecoration selectedItemBorderStyle() => BoxDecoration(
    boxShadow: [BoxShadow(color: context.colors.borderDefault, blurRadius: 3)],
    border: Border.all(color: context.colors.textPrimary),
    color: context.colors.surfaceElevated,
    borderRadius: BorderRadius.circular(UiUtils.borderRadiusOf10),
  );

  BoxDecoration normalBoxDecoration() => BoxDecoration(
    color: context.colors.surfaceElevated,
    borderRadius: BorderRadius.circular(UiUtils.borderRadiusOf10),
  );

  // Re-derives selectedDeliverableOption only when the current pick is no
  // longer valid, instead of unconditionally overwriting it. Both the
  // regular-cart and custom-job-request listeners rerun on every cart
  // mutation (manage_cart, promo code, quantity change...) — overwriting
  // unconditionally silently discarded an explicit "At Store" pick before
  // place_order ever saw it.
  void _syncSelectedDeliverableOption({
    required final bool atStoreAvailable,
    required final bool atDoorstepAvailable,
  }) {
    final bool currentSelectionStillValid =
        (selectedDeliverableOption == deliverableOptions[1]['title'] &&
            atStoreAvailable) ||
        (selectedDeliverableOption == deliverableOptions[0]['title'] &&
            atDoorstepAvailable);
    if (!currentSelectionStillValid) {
      selectedDeliverableOption = atDoorstepAvailable
          ? deliverableOptions[0]['title']!
          : deliverableOptions[1]['title']!;
    }
  }

  void placeOrder() {
    ClarityService.logAction(
      ClarityActions.cartCheckoutTapped,
      _buildCartAnalyticsPayload(
        paymentMethod: selectedPaymentMethod,
        paymentAmount: _currentCartTotalAmount(),
      ),
    );
    context.read<PlaceOrderCubit>().placeOrder(
      status: "awaiting",
      orderId: widget.orderID ?? '',
      customJobRequestId: widget.customJobRequestId ?? '',
      bidderId: widget.providerId,
      // this is partner id which we will get from bidder
      selectedAddressID: selectedAddress?.id,
      promoCodeId: appliedPromocode?.id ?? '',
      paymentMethod: selectedPaymentMethod!,
      orderNote: _instructionController.text.trim().toString(),
      dateOfService: selectedDate!,
      startingTime: selectedTime!,
      isAtStoreOptionSelected: selectedDeliverableOption == "atStore"
          ? "1"
          : "0",
      cartId: context.read<CartCubit>().getCartId(isFrom: widget.isFrom),
    );
  }

  Widget buildPaymentMethodsList({final VoidCallback? onSelected}) =>
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: enabledPaymentMethods.length,
        separatorBuilder: (final context, final index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: CustomSizedBox(
            height: 1,
            width: double.infinity,
            child: DashedRect(
              color: context.colors.borderDefault,
              strokeWidth: 1,
              gap: 4,
            ),
          ),
        ),
        itemBuilder: (context, index) {
          final Map<String, dynamic> paymentMethod =
              enabledPaymentMethods[index];
          return CustomRadioOptionsWidget(
            image: paymentMethod["image"] ?? '',
            title: paymentMethod["title"] ?? '',
            value: paymentMethod["paymentType"] ?? '',
            groupValue: selectedPaymentMethod ?? '',
            applyAccentColor: false,
            onChanged: (final Object? selectedValue) {
              selectedPaymentMethod = selectedValue.toString();
              paymentButtonName.value = selectedValue.toString() == "cod"
                  ? "bookService"
                  : "makePayment";
              setState(() {});
              onSelected?.call();
            },
          );
        },
      );

  bool computeShowPaymentOptions(final bool isCustomJobRequest) {
    final bool isPayLaterAllowed = isCustomJobRequest
        ? context.read<SystemSettingCubit>().isPayLaterAllowedGlobally
        : context.read<CartCubit>().isPayLaterAllowed(isFrom: widget.isFrom);

    final bool isOnlinePaymentAllowed = isCustomJobRequest
        ? context.read<SystemSettingCubit>().isOnlinePaymentAllowedGlobally
        : context.read<CartCubit>().isOnlinePaymentAllowed(
            isFrom: widget.isFrom,
          );

    final bool isMoreThanOnePaymentGatewayEnabled = context
        .read<SystemSettingCubit>()
        .isMoreThanOnePaymentGatewayEnabled();

    return (isCustomJobRequest &&
            isPayLaterAllowed &&
            isOnlinePaymentAllowed) ||
        (isCustomJobRequest &&
            isOnlinePaymentAllowed &&
            isMoreThanOnePaymentGatewayEnabled) ||
        (!isCustomJobRequest && isPayLaterAllowed && isOnlinePaymentAllowed) ||
        (!isCustomJobRequest &&
            isOnlinePaymentAllowed &&
            isMoreThanOnePaymentGatewayEnabled);
  }

  Widget buildPayUsingPill() {
    final Map<String, dynamic> current = enabledPaymentMethods.firstWhere(
      (final m) => m["paymentType"] == selectedPaymentMethod,
      orElse: () =>
          enabledPaymentMethods.isNotEmpty ? enabledPaymentMethods.first : {},
    );
    return CustomInkWellContainer(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        UiUtils.removeFocus();
        UiUtils.showBottomSheet(
          context: context,
          enableDrag: true,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.colors.backgroundTertiary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                const CustomSizedBox(height: 16),
                CustomText(
                  'selectPayment'.translate(context: context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textPrimary,
                ),
                const CustomSizedBox(height: 16),
                Divider(height: 1, color: context.colors.borderDefault),
                const CustomSizedBox(height: 16),
                buildPaymentMethodsList(
                  onSelected: () => Navigator.pop(context),
                ),
                CustomSizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomText(
            'payUsing'.translate(context: context),
            fontSize: 11,
            color: context.colors.textSecondary,
          ),
          const CustomSizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((current["image"] ?? '').toString().isNotEmpty) ...[
                CustomContainer(
                  borderRadius: 4,
                  child: CustomSvgPicture(
                    svgImage: current["image"].toString(),
                    height: 18,
                    width: 18,
                  ),
                ),
                const CustomSizedBox(width: 4),
              ],
              CustomText(
                (current["title"] ?? '').toString().translate(context: context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                maxLines: 1,
                color: context.colors.textPrimary,
              ),
              CustomSvgPicture(
                svgImage: AppAssets.downArrow,
                height: 20,
                width: 20,
                color: context.colors.iconSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  //we will get cart total amount form cart cubit or my request cart cubit
  //and if amount is from cart cubit and promocode is applied then we will subtract that amount for online pay
  double _computeOnlinePaymentAmount() => widget.isFrom == 'customJobRequest'
      ? double.parse(
          context.read<MyRequestCartCubit>().getCartTotalAmount(
            isFrom: widget.isFrom,
            isAtStoreBooked: selectedDeliverableOption == "atStore",
          ),
        )
      : double.parse(
              context.read<CartCubit>().getCartTotalAmount(
                isFrom: widget.isFrom,
                isAtStoreBooked: selectedDeliverableOption == "atStore",
              ),
            ) -
            promoCodeDiscount;

  Widget continueButtonContainer(final BuildContext context) {
    final bool isCartDataReady = widget.isFrom == "customJobRequest"
        ? context.watch<MyRequestCartCubit>().state is MyRequestCartSuccess
        : context.watch<CartCubit>().state is CartFetchSuccess;

    if (!isCartDataReady) {
      return CustomContainer(
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
        color: context.colors.surfacePrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: CustomShimmerLoadingContainer(
          height: 48,
          width: context.screenWidth,
          borderRadius: UiUtils.borderRadiusOf12,
        ),
      );
    }

    return BlocConsumer<PlaceOrderCubit, PlaceOrderState>(
      listener: (context, placeOrderState) {
        if (placeOrderState is PlaceOrderSuccess) {
          if (!placeOrderState.isError) {
            placedOrderId = placeOrderState.orderId;

            final double cartTotalAmount = _computeOnlinePaymentAmount();

            if (selectedPaymentMethod == "cod") {
              _navigateToOrderConfirmation(isSuccess: true);
            } else {
              ClarityService.logAction(
                ClarityActions.paymentStarted,
                _buildCartAnalyticsPayload(
                  paymentMethod: selectedPaymentMethod,
                  paymentAmount: cartTotalAmount.toString(),
                ),
              );
              ClarityService.setTag(
                'payment_method',
                selectedPaymentMethod ?? '',
              );
              if (selectedPaymentMethod == 'stripe') {
                openStripePaymentGateway(
                  orderAmount: cartTotalAmount,
                  placedOrderId: placeOrderState.orderId,
                );
              } else if (selectedPaymentMethod == 'razorpay') {
                openRazorPayGateway(
                  orderAmount: cartTotalAmount,
                  placedOrderId: placeOrderState.orderId,
                  razorpayOrderId: placeOrderState.razorpayOrderId,
                );
              } else if (selectedPaymentMethod == 'paystack') {
                _openWebviewPaymentGateway(
                  webviewLink: placeOrderState.paystackLink,
                );
              } else if (selectedPaymentMethod == 'flutterwave') {
                _openWebviewPaymentGateway(
                  webviewLink: placeOrderState.flutterwaveLink,
                );
              } else if (selectedPaymentMethod == 'paypal') {
                _openWebviewPaymentGateway(
                  webviewLink: placeOrderState.paypalLink,
                );
              } else if (selectedPaymentMethod == 'xendit') {
                _openWebviewPaymentGateway(
                  webviewLink: placeOrderState.xenditLink,
                );
              } else if (selectedPaymentMethod == 'cashfree') {
                openCashfreePaymentGateway(
                  orderAmount: cartTotalAmount,
                  localOrderId: placeOrderState.orderId,
                  cashfreePaymentSessionId:
                      placeOrderState.cashfreePaymentSessionId,
                  cashfreeOrderId: placeOrderState.cashfreeOrderId,
                );
              } else {
                UiUtils.showMessage(
                  context,
                  'onlinePaymentNotAvailableNow'.translate(context: context),
                  ToastificationType.warning,
                );
              }
            }
          } else {
            UiUtils.showMessage(
              context,
              placeOrderState.message.translate(context: context),
              ToastificationType.error,
            );
          }
        }
        if (placeOrderState is PlaceOrderFailure) {
          UiUtils.showMessage(
            context,
            placeOrderState.errorMessage.translate(context: context),
            ToastificationType.error,
          );
        }
      },
      builder: (context, state) {
        return BlocConsumer<
          CheckProviderAvailabilityCubit,
          CheckProviderAvailabilityState
        >(
          listener:
              (
                final context,
                CheckProviderAvailabilityState checkProviderAvailabilityState,
              ) {
                if (checkProviderAvailabilityState
                    is CheckProviderAvailabilityFetchSuccess) {
                  // ApiClient throws on error:true (see apiClient.dart), so
                  // that case never actually lands here in practice — it
                  // surfaces as CheckProviderAvailabilityFetchFailure below.
                  // Kept for safety in case that ever changes.
                  _isLocationUnavailableAtDoorstep.value =
                      checkProviderAvailabilityState.error;
                  if (checkProviderAvailabilityState.error) {
                    UiUtils.showMessage(
                      context,
                      'serviceNotAvailableAtSelectedAddress'.translate(
                        context: context,
                      ),
                      ToastificationType.warning,
                    );
                  } else if (selectedDate != null && selectedTime != null) {
                    context.read<ValidateCustomTimeCubit>().validateCustomTime(
                      providerId: widget.providerId,
                      selectedDate: selectedDate,
                      selectedTime: selectedTime,
                      orderId: widget.orderID,
                      customJobRequestId: widget.customJobRequestId,
                    );
                  }
                } else if (checkProviderAvailabilityState
                    is CheckProviderAvailabilityFetchFailure) {
                  // The real "no coverage" path: ApiClient throws on
                  // error:true, landing here with the backend's own message.
                  _isLocationUnavailableAtDoorstep.value = true;
                  UiUtils.showMessage(
                    context,
                    checkProviderAvailabilityState.errorMessage,
                    ToastificationType.error,
                  );
                }
              },
          builder:
              (
                final context,
                CheckProviderAvailabilityState checkProviderAvailabilityState,
              ) {
                return BlocConsumer<
                  ValidateCustomTimeCubit,
                  ValidateCustomTimeState
                >(
                  listener:
                      (
                        final BuildContext context,
                        final ValidateCustomTimeState validateCustomTimeState,
                      ) {
                        if (validateCustomTimeState
                            is ValidateCustomTimeSuccess) {
                          if (!validateCustomTimeState.error) {
                            placeOrder();
                          } else {
                            UiUtils.showMessage(
                              context,
                              validateCustomTimeState.message,
                              ToastificationType.error,
                            );
                          }
                        } else if (validateCustomTimeState
                            is ValidateCustomTimeFailure) {
                          UiUtils.showMessage(
                            context,
                            validateCustomTimeState.errorMessage,
                            ToastificationType.error,
                          );
                        }
                      },
                  builder:
                      (
                        final BuildContext context,
                        final ValidateCustomTimeState validateCustomTimeState,
                      ) {
                        final bool isCustomJobRequest =
                            widget.isFrom == "customJobRequest";
                        final bool showPaymentOptionsPill =
                            computeShowPaymentOptions(isCustomJobRequest) &&
                            enabledPaymentMethods.isNotEmpty;
                        return CustomContainer(
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 16,
                              offset: const Offset(0, 2),
                              color: Colors.black.withValues(alpha: 0.08),
                            ),
                          ],
                          color: context.colors.surfacePrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: ValueListenableBuilder(
                            valueListenable: paymentButtonName,
                            builder: (context, value, _) {
                              final Widget payButton = CustomRoundedButton(
                                onTap: () {
                                  if (validateCustomTimeState
                                          is ValidateCustomTimeInProgress ||
                                      checkProviderAvailabilityState
                                          is CheckProviderAvailabilityFetchInProgress) {
                                    return;
                                  }

                                  if (selectedTime == null ||
                                      selectedDate == null) {
                                    UiUtils.showMessage(
                                      context,
                                      'pleaseSelectDateAndTime'.translate(
                                        context: context,
                                      ),
                                      ToastificationType.warning,
                                    );
                                    return;
                                  }

                                  if (context
                                          .read<MyRequestCartCubit>()
                                          .checkAtDoorstepProviderAvailable(
                                            isFrom: widget.isFrom,
                                          ) &&
                                      selectedDeliverableOption ==
                                          deliverableOptions[0]["title"]) {
                                    if (selectedAddress == null) {
                                      UiUtils.showMessage(
                                        context,
                                        'pleaseSelectAddress'.translate(
                                          context: context,
                                        ),
                                        ToastificationType.warning,
                                      );
                                    } else {
                                      context
                                          .read<
                                            CheckProviderAvailabilityCubit
                                          >()
                                          .checkProviderAvailability(
                                            customJobRequestId: widget
                                                .bidder
                                                ?.customJobRequestId,
                                            bidderId: widget.bidder?.providerId
                                                .toString(),
                                            isAuthTokenRequired: true,
                                            checkingAtCheckOut: '1',
                                            latitude:
                                                selectedAddress?.lattitude
                                                    .toString() ??
                                                '',
                                            longitude:
                                                selectedAddress?.longitude
                                                    .toString() ??
                                                '',
                                          );
                                    }
                                  } else if (widget.isFrom !=
                                          "customJobRequest" &&
                                      context
                                          .read<CartCubit>()
                                          .checkAtDoorstepProviderAvailable(
                                            isFrom: widget.isFrom,
                                          ) &&
                                      selectedDeliverableOption ==
                                          deliverableOptions[0]["title"]) {
                                    if (selectedAddress == null) {
                                      UiUtils.showMessage(
                                        context,
                                        'pleaseSelectAddress'.translate(
                                          context: context,
                                        ),
                                        ToastificationType.warning,
                                      );
                                    } else {
                                      context
                                          .read<
                                            CheckProviderAvailabilityCubit
                                          >()
                                          .checkProviderAvailability(
                                            orderId: widget.orderID,
                                            isAuthTokenRequired: true,
                                            checkingAtCheckOut: '1',
                                            latitude:
                                                selectedAddress?.lattitude
                                                    .toString() ??
                                                '',
                                            longitude:
                                                selectedAddress?.longitude
                                                    .toString() ??
                                                '',
                                          );
                                    }
                                  } else {
                                    placeOrder();
                                  }
                                },
                                widthPercentage: 1,
                                backgroundColor: context.colors.backgroundBrand,
                                buttonTitle: selectedPaymentMethod == "cod"
                                    ? 'bookService'.translate(context: context)
                                    : '${'pay'.translate(context: context)} ${_computeOnlinePaymentAmount().toStringAsFixed(2).priceFormat(context)}',
                                showBorder: false,
                                radius: UiUtils.borderRadiusOf12,
                                textSize: 16,
                                fontWeight: FontWeight.w500,
                                child:
                                    state is PlaceOrderInProgress ||
                                        checkProviderAvailabilityState
                                            is CheckProviderAvailabilityFetchInProgress ||
                                        validateCustomTimeState
                                            is ValidateCustomTimeInProgress
                                    ? Center(
                                        child: CustomCircularProgressIndicator(
                                          color:
                                              context.colors.textInverseLight,
                                        ),
                                      )
                                    : null,
                              );
                              if (!showPaymentOptionsPill) return payButton;
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  buildPayUsingPill(),
                                  const CustomSizedBox(width: 12),
                                  Expanded(child: payButton),
                                ],
                              );
                            },
                          ),
                        );
                      },
                );
              },
        );
      },
    );
  }

  Widget getTitle({required String title}) {
    return CustomText(
      title.translate(context: context),
      fontSize: 16,
      color: context.colors.textPrimary,
      fontWeight: FontWeight.bold,
    );
  }

  int currentServiceCount(final CartState cartState) {
    if (widget.isFrom == "customJobRequest") return 1;
    if (cartState is CartFetchSuccess) {
      final List<CartDetails>? details = widget.isFrom == "cart"
          ? cartState.cartData.cartDetails
          : cartState.reOrderCartData?.cartDetails;
      if (details == null) return 0;
      // Count distinct services, not raw rows — the cart API can split one
      // service across more than one row.
      final Set<String> distinctServiceIds = details
          .map((final d) => d.serviceId)
          .whereType<String>()
          .where((final id) => id.isNotEmpty)
          .toSet();
      return distinctServiceIds.isNotEmpty
          ? distinctServiceIds.length
          : details.length;
    }
    return 0;
  }

  Widget buildAppBarSubtitle(
    final BuildContext context, {
    required final int serviceCount,
    required final String amount,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CustomText(
        '$serviceCount ${(serviceCount > 1 ? "services" : "service").translate(context: context)}',
        fontSize: 12,
        color: context.colors.textSecondary,
      ),
      const CustomSizedBox(width: 6),
      CustomContainer(
        height: 4,
        width: 4,
        shape: BoxShape.circle,
        color: context.colors.textTertiary,
      ),
      const CustomSizedBox(width: 6),
      CustomText(amount, fontSize: 12, color: context.colors.textSecondary),
    ],
  );

  Widget buildCheckoutAppBarTitle(final bool isCustomJobRequest) {
    Widget titleColumn(final int serviceCount, final String amount) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomText(
          widget.companyName.isNotEmpty
              ? widget.companyName
              : widget.providerName,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          maxLines: 1,
          color: context.colors.textPrimary,
        ),
        const CustomSizedBox(height: 2),
        buildAppBarSubtitle(
          context,
          serviceCount: serviceCount,
          amount: amount,
        ),
      ],
    );

    if (isCustomJobRequest) {
      return BlocBuilder<MyRequestCartCubit, MyRequestCartState>(
        builder: (context, state) => titleColumn(
          1,
          state is MyRequestCartSuccess
              ? _currentCartTotalAmount().priceFormat(context)
              : '',
        ),
      );
    }
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) => titleColumn(
        currentServiceCount(state),
        state is CartFetchSuccess
            ? _currentCartTotalAmount().priceFormat(context)
            : '',
      ),
    );
  }

  bool _hasMultipleProviderCarts(final CartState cartState) =>
      cartState is CartFetchSuccess &&
      (cartState.cartData.otherCarts?.any(
            (final c) => c.cartDetails?.isNotEmpty ?? false,
          ) ??
          false);

  void _onProviderAvatarTap() {
    final CartState cartState = context.read<CartCubit>().state;
    final bool hasMultipleProviderCarts = _hasMultipleProviderCarts(cartState);

    if (widget.isFrom == "cart" && hasMultipleProviderCarts) {
      Navigator.pop(context);
      final BuildContext rootContext = UiUtils.rootNavigatorKey.currentContext!;
      UiUtils.showBottomSheet(
        context: rootContext,
        enableDrag: true,
        child: const CartListBottomSheet(),
      ).then((final value) {
        if (value is Map) {
          Navigator.of(rootContext).pushNamed(
            scheduleScreenRoute,
            arguments: {
              "isFrom": "cart",
              "providerName": value["providerName"] ?? '',
              "providerId": value["providerId"] ?? "0",
              "companyName": value["companyName"] ?? '',
              "providerAdvanceBookingDays": value["providerAdvanceBookingDays"],
              "cartId": value["cartId"] ?? '',
            },
          );
        }
      });
      return;
    }

    Navigator.pushNamed(
      context,
      providerRoute,
      arguments: {"providerId": widget.providerId},
    );
  }

  Widget buildProviderAvatarAction() {
    final bool hasMultipleProviderCarts = _hasMultipleProviderCarts(
      context.watch<CartCubit>().state,
    );
    if (!hasMultipleProviderCarts) return const CustomSizedBox();

    final bool canOpenProvider =
        widget.providerId.isNotEmpty && widget.providerId != "0";
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 16),
      child: CustomInkWellContainer(
        borderRadius: BorderRadius.circular(20),
        onTap: canOpenProvider ? _onProviderAvatarTap : null,
        child: CustomContainer(
          padding: const EdgeInsets.all(8),
          color: context.colors.surfacePrimary,
          borderRadius: 24,
          child: CustomSvgPicture(
            svgImage: AppAssets.userSwitch,
            height: 24,
            width: 24,
            color: context.colors.iconPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(final BuildContext context) {
    // Extract conditions into variables
    final bool isCustomJobRequest = widget.isFrom == "customJobRequest";

    return ValueListenableBuilder(
      valueListenable: isPaymentProcessing,
      builder: (context, paymentProcessing, child) {
        return PopScope(
          canPop: !paymentProcessing,
          child: AnnotatedSafeArea(
            isAnnotated: true,
            child: Scaffold(
              backgroundColor: context.colors.backgroundSecondary,
              appBar: UiUtils.getSimpleAppBar(
                context: context,
                titleWidget: buildCheckoutAppBarTitle(isCustomJobRequest),
                actions: [
                  if (widget.isFrom != 'customJobRequest')
                    buildProviderAvatarAction(),
                ],
                onLeadingTap: paymentProcessing ? () {} : null,
              ),
              body: isCustomJobRequest
                  ? _buildMainScheduleContent(
                      context: context,
                      isCustomJobRequest: isCustomJobRequest,
                    )
                  : BlocConsumer<CartCubit, CartState>(
                      listener: (context, cartState) {
                        if (cartState is CartFetchSuccess) {
                          enabledPaymentMethods = context
                              .read<SystemSettingCubit>()
                              .getEnabledPaymentMethods(
                                isOnlinePaymentAllowed: context
                                    .read<CartCubit>()
                                    .isOnlinePaymentAllowed(
                                      isFrom: widget.isFrom,
                                    ),
                                isPayLaterAllowed: context
                                    .read<CartCubit>()
                                    .isPayLaterAllowed(isFrom: widget.isFrom),
                              );
                          _syncSelectedDeliverableOption(
                            atStoreAvailable: context
                                .read<CartCubit>()
                                .checkAtStoreProviderAvailable(
                                  isFrom: widget.isFrom,
                                ),
                            atDoorstepAvailable: context
                                .read<CartCubit>()
                                .checkAtDoorstepProviderAvailable(
                                  isFrom: widget.isFrom,
                                ),
                          );

                          if (enabledPaymentMethods.isNotEmpty) {
                            selectedPaymentMethod =
                                enabledPaymentMethods[0]['paymentType'];
                          } else {
                            selectedPaymentMethod = "cod";
                          }
                          _checkProviderAvailabilityForSelectedAddress();
                          setState(() {});
                        }
                      },
                      builder: (context, cartState) {
                        if (cartState is CartFetchInProgress) {
                          return Center(
                            child: CustomCircularProgressIndicator(
                              color: context.colors.textBrand,
                            ),
                          );
                        }
                        if (cartState is CartFetchFailure) {
                          return ErrorContainer(
                            errorMessage: cartState.errorMessage,
                            onTapRetry: () {
                              context.read<CartCubit>().getCartDetails(
                                isReorderCart: widget.isFrom == "reorder",
                                reOrderId: widget.orderID,
                              );
                            },
                          );
                        }
                        return _buildMainScheduleContent(
                          context: context,
                          isCustomJobRequest: isCustomJobRequest,
                        );
                      },
                    ),
              bottomSheet: continueButtonContainer(context),
            ),
          ),
        );
      },
    );
  }

  void _toggleBillDetails() =>
      setState(() => isBillDetailsExpanded = !isBillDetailsExpanded);

  Widget _buildBillToggleButton() => CustomInkWellContainer(
    borderRadius: BorderRadius.circular(24),
    onTap: _toggleBillDetails,
    child: CustomContainer(
      padding: const EdgeInsets.all(8),
      color: context.colors.backgroundSecondary,
      shape: BoxShape.circle,
      child: CustomSvgPicture(
        svgImage: isBillDetailsExpanded
            ? AppAssets.upArrow
            : AppAssets.downArrow,
        height: 20,
        width: 20,
        color: context.colors.iconPrimary,
      ),
    ),
  );

  Widget _buildCollapsedBillSummary({
    required final String finalTotalText,
    final String? originalTotalText,
    final String? savedBadgeText,
  }) {
    final bool hasDiscount = originalTotalText != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomContainer(
          padding: const EdgeInsets.all(8),
          color: context.colors.backgroundSecondary,
          borderRadius: 12,
          child: CustomSvgPicture(
            svgImage: AppAssets.fileText,
            height: 16,
            width: 16,
            color: context.colors.iconPrimary,
          ),
        ),
        const CustomSizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomText(
                    '${'totalBill'.translate(context: context)} ',
                    fontSize: 14,
                    color: context.colors.textPrimary,
                  ),
                  if (hasDiscount) ...[
                    CustomText(
                      '$originalTotalText, ',
                      fontSize: 14,
                      color: context.colors.textPrimary,
                      showLineThrough: true,
                    ),
                  ],
                  CustomText(
                    finalTotalText,
                    fontSize: 14,
                    fontWeight: hasDiscount ? FontWeight.w600 : FontWeight.w400,
                    color: context.colors.textPrimary,
                  ),
                ],
              ),
              if (savedBadgeText != null) ...[
                const CustomSizedBox(height: 4),
                CustomContainer(
                  padding: const EdgeInsets.all(4),
                  color: context.colors.backgroundBrandSubtle,
                  borderRadius: 4,
                  child: CustomText(
                    savedBadgeText,
                    fontSize: 11,
                    color: context.colors.textBrand,
                  ),
                ),
              ],
            ],
          ),
        ),
        const CustomSizedBox(width: 8),
        _buildBillToggleButton(),
      ],
    );
  }

  Widget buildBillDetailsCard({
    required final List<Widget> rows,
    required final bool showSavedBanner,
    required final String savedAmountText,
    required final String finalTotalText,
    final String? originalTotalText,
    final String? savedBadgeText,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: CustomContainer(
      padding: const EdgeInsets.all(12),
      color: context.colors.surfacePrimary,
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBillDetailsExpanded) ...[
            Row(
              children: [
                Expanded(
                  child: CustomText(
                    'billDetails'.translate(context: context),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textPrimary,
                  ),
                ),
                _buildBillToggleButton(),
              ],
            ),
            const CustomSizedBox(height: 12),
            Divider(height: 1, color: context.colors.borderDefault),
            const CustomSizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            ),
            if (showSavedBanner) ...[
              const CustomSizedBox(height: 12),
              CustomContainer(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                color: context.colors.backgroundSuccessSubtle,
                borderRadius: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomSvgPicture(
                      svgImage: AppAssets.verified,
                      height: 24,
                      width: 24,
                      avoideResponsive: true,
                      color: context.colors.backgroundSuccess,
                    ),
                    const CustomSizedBox(width: 8),
                    Flexible(
                      child: CustomText(
                        savedAmountText,
                        fontSize: 12,
                        color: context.colors.textSuccess,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else
            _buildCollapsedBillSummary(
              finalTotalText: finalTotalText,
              originalTotalText: originalTotalText,
              savedBadgeText: savedBadgeText,
            ),
        ],
      ),
    ),
  );

  Widget _buildMainScheduleContent({
    required BuildContext context,
    required bool isCustomJobRequest,
  }) {
    final bool isAtStoreProviderAvailable = isCustomJobRequest
        ? context.read<MyRequestCartCubit>().checkAtStoreProviderAvailable(
            isFrom: widget.isFrom,
          )
        : context.read<CartCubit>().checkAtStoreProviderAvailable(
            isFrom: widget.isFrom,
          );

    final bool isAtDoorstepProviderAvailable = isCustomJobRequest
        ? context.read<MyRequestCartCubit>().checkAtDoorstepProviderAvailable(
            isFrom: widget.isFrom,
          )
        : context.read<CartCubit>().checkAtDoorstepProviderAvailable(
            isFrom: widget.isFrom,
          );

    final bool showServiceDeliverableOptions =
        isAtStoreProviderAvailable && isAtDoorstepProviderAvailable;

    final bool showAddressSelector =
        selectedDeliverableOption == deliverableOptions[0]["title"] &&
        isAtDoorstepProviderAvailable;

    final CartState cartState = context.read<CartCubit>().state;
    final Cart? cartData = !isCustomJobRequest && cartState is CartFetchSuccess
        ? cartState.cartData
        : null;
    final MyRequestCartState myRequestCartState = context
        .read<MyRequestCartCubit>()
        .state;
    final BidProvider? bidderData =
        isCustomJobRequest && myRequestCartState is MyRequestCartSuccess
        ? myRequestCartState.bidderData
        : null;
    final bool isAtStoreSelected =
        selectedDeliverableOption == deliverableOptions[1]["title"];

    // Once the last item is removed via manage_cart/remove_from_cart,
    // cartData comes back with an empty cartDetails list — the services
    // list already hides itself for that (see buildServicesList), but
    // Service Location / date selector / offers weren't checking this and
    // kept showing stale sections for a cart that no longer has anything
    // in it.
    final bool hasCartServices =
        cartData == null || (cartData.cartDetails?.isNotEmpty ?? false);

    final GetAllPromocodesState promoState = context
        .watch<GetAllPromocodesCubit>()
        .state;
    // Hide the whole "Offers & Coupons" container when there's nothing to
    // suggest and nothing already applied — an empty container with just a
    // header/"view all" link looked broken.
    final bool hasPromocodesToShow =
        (promoState is GetAllPromocodesFetchSuccess &&
            promoState.promocodeList.isNotEmpty) ||
        appliedPromocode != null;

    return SingleChildScrollView(
      clipBehavior: Clip.none,
      padding: EdgeInsetsDirectional.only(
        bottom: kBottomNavigationBarHeight.rh(context) + 40.rh(context),
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (hasCartServices &&
              (showAddressSelector || showServiceDeliverableOptions)) ...[
            buildServiceLocationSection(
              showAddress: showAddressSelector,
              showDeliverableOptions: showServiceDeliverableOptions,
              providerAddress: cartData?.providerAddress,
              providerLatitude: cartData?.providerLatitude,
              providerLongitude: cartData?.providerLongitude,
            ),
          ],
          if (isAtStoreSelected &&
              (isCustomJobRequest
                  ? bidderData?.distance != null &&
                        bidderData?.providerLatitude != null &&
                        bidderData?.providerLongitude != null
                  : cartData?.distance != null &&
                        cartData?.providerLatitude != null &&
                        cartData?.providerLongitude != null))
            ProviderDistanceBanner(
              distanceInKm: isCustomJobRequest
                  ? bidderData!.distance!
                  : cartData!.distance!,
              providerAddress: isCustomJobRequest
                  ? (bidderData?.providerAddress ?? '')
                  : (cartData?.providerAddress ?? ''),
              providerLatitude: isCustomJobRequest
                  ? bidderData!.providerLatitude!
                  : cartData!.providerLatitude!,
              providerLongitude: isCustomJobRequest
                  ? bidderData!.providerLongitude!
                  : cartData!.providerLongitude!,
            ),
          if (selectedDeliverableOption == deliverableOptions[0]["title"])
            ValueListenableBuilder<bool>(
              valueListenable: _isLocationUnavailableAtDoorstep,
              builder: (context, isUnavailable, child) => isUnavailable
                  ? ServiceUnavailableBanner(
                      latitude: selectedAddress?.lattitude.toString() ?? '',
                      longitude: selectedAddress?.longitude.toString() ?? '',
                      address: selectedAddress?.address ?? '',
                    )
                  : const CustomSizedBox(),
            ),

          if (!isCustomJobRequest) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: buildServicesList(),
            ),
          ],
          if (hasCartServices)
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: 16.rw(context),
                end: 16.rw(context),
                top: !isCustomJobRequest ? 0.rh(context) : 16.rh(context),
              ),
              child: buildDateSelector(),
            ),
          if (isCustomJobRequest) ...[
            const CustomSizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _instructionController,
                builder: (context, value, child) => value.text.trim().isEmpty
                    ? GestureDetector(
                        onTap: _openProviderInstructionBottomSheet,
                        child: _buildViewProviderInstructionField(
                          fullWidth: true,
                        ),
                      )
                    : CustomContainer(
                        color: context.colors.backgroundPrimary,
                        borderRadius: 12,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        child: _buildFilledProviderInstructionField(value.text),
                      ),
              ),
            ),
          ],
          if (!isCustomJobRequest &&
              hasCartServices &&
              hasPromocodesToShow) ...[
            const CustomSizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CustomContainer(
                padding: const EdgeInsets.all(12),
                color: context.colors.surfacePrimary,
                borderRadius: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CustomText(
                            'offerAndCoupons'.translate(context: context),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        CustomInkWellContainer(
                          onTap: () {
                            if (widget.providerId == "0") {
                              UiUtils.showMessage(
                                context,
                                'somethingWentWrong'.translate(
                                  context: context,
                                ),
                                ToastificationType.warning,
                              );
                              return;
                            }
                            Navigator.pushNamed(
                              context,
                              promocodeScreen,
                              arguments: {
                                "isFrom": widget.isFrom,
                                "providerID": widget.providerId,
                                "isAtStoreOptionSelected":
                                    selectedDeliverableOption == "atStore"
                                    ? "1"
                                    : "0",
                              },
                            ).then((final Object? value) {
                              if (value != null) {
                                final parameter = value as Map;
                                promoCodeDiscount = double.parse(
                                  parameter["discount"],
                                );
                                appliedPromocode =
                                    parameter["appliedPromocode"];
                                setState(() {});
                              }
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CustomText(
                                'viewAll'.translate(context: context),
                                fontSize: 14,
                                color: context.colors.textBrand,
                              ),
                              const CustomSizedBox(width: 4),
                              CustomSvgPicture(
                                svgImage:
                                    Directionality.of(context) ==
                                        TextDirection.rtl
                                    ? AppAssets.backArrow
                                    : AppAssets.backArrowLtr,
                                height: 20,
                                width: 20,
                                color: context.colors.iconBrand,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const CustomSizedBox(height: 12),
                    Divider(height: 1, color: context.colors.borderDefault),
                    const CustomSizedBox(height: 12),
                    if (appliedPromocode != null)
                      _buildOfferRow(
                        discountLabel: _promoDiscountLabel(appliedPromocode!),
                        subtitleLabel: _promoMinOrderLabel(appliedPromocode!),
                        buttonLabel: 'remove'.translate(context: context),
                        buttonColor: context.colors.textError,
                        onButtonTap: () {
                          promoCodeDiscount = 0.0;
                          appliedPromocode = null;
                          setState(() {});
                        },
                      )
                    else
                      _buildSuggestedPromoRow(),
                  ],
                ),
              ),
            ),
          ],
          if (widget.isFrom == "customJobRequest") ...[
            const CustomSizedBox(height: 16),
            BlocBuilder<MyRequestCartCubit, MyRequestCartState>(
              builder: (final BuildContext context, final MyRequestCartState state) {
                if (state is MyRequestCartInProgress) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: context.colors.iconBrand,
                    ),
                  );
                }
                if (state is MyRequestCartSuccess) {
                  final double customFinalTotal =
                      (double.tryParse(
                            state.bidderData.finalTotal ??
                                state.bidderData.counterPrice,
                          ) ??
                          0) +
                      (selectedDeliverableOption != "atStore"
                          ? (double.tryParse(
                                  state.bidderData.visitingCharges ?? "0",
                                ) ??
                                0)
                          : 0);
                  final String customFinalTotalText = customFinalTotal
                      .toStringAsFixed(2)
                      .priceFormat(context);
                  final List<Widget> rows = [
                    ChargesTile(
                      title: 'subTotal'.translate(context: context),
                      value:
                          (context.read<SystemSettingCubit>().showTaxOnCheckout
                                  ? state.bidderData.counterPrice
                                  : state.bidderData.finalTotal ??
                                        state.bidderData.counterPrice)
                              .priceFormat(context),
                      fontSize: 14,
                      fontweight: FontWeight.w400,
                    ),
                    if (context.read<SystemSettingCubit>().showTaxOnCheckout &&
                        (double.tryParse(state.bidderData.taxAmount ?? "0") ??
                                0.0) >
                            0) ...[
                      const CustomSizedBox(height: 8),
                      ChargesTile(
                        title: 'tax'.translate(context: context),
                        value:
                            "+ ${(state.bidderData.taxAmount ?? "0").priceFormat(context)}",
                        fontSize: 14,
                      ),
                    ],
                    if (state.bidderData.visitingCharges != null &&
                        state.bidderData.visitingCharges != '0' &&
                        state.bidderData.visitingCharges != '' &&
                        state.bidderData.visitingCharges != 'null' &&
                        selectedDeliverableOption != "atStore") ...[
                      const CustomSizedBox(height: 8),
                      ChargesTile(
                        title: 'visitingCharge'.translate(context: context),
                        value:
                            '+ ${state.bidderData.visitingCharges!.priceFormat(context)}',
                        fontSize: 14,
                        fontweight: FontWeight.w400,
                      ),
                    ],
                    if (selectedDeliverableOption != "atStore") ...[
                      const CustomSizedBox(height: 8),
                      Divider(height: 1, color: context.colors.borderDefault),
                      const CustomSizedBox(height: 8),
                      ChargesTile(
                        title: 'totalAmount'.translate(context: context),
                        value: customFinalTotalText,
                        fontSize: 16,
                        fontweight: FontWeight.w700,
                        titleColor: context.colors.textPrimary,
                        valueColor: context.colors.textBrand,
                      ),
                    ],
                  ];
                  return buildBillDetailsCard(
                    rows: rows,
                    showSavedBanner: false,
                    savedAmountText: '',
                    finalTotalText: customFinalTotalText,
                  );
                }
                return const CustomSizedBox();
              },
            ),
          ],
          if (widget.isFrom != "customJobRequest") ...[
            const CustomSizedBox(height: 16),
            BlocBuilder<CartCubit, CartState>(
              builder: (final BuildContext context, final CartState state) {
                if (state is CartFetchSuccess) {
                  if (state.cartData.cartDetails == null &&
                      state.reOrderCartData?.cartDetails == null) {
                    return const CustomSizedBox();
                  }
                  final bool showTax = context
                      .read<SystemSettingCubit>()
                      .showTaxOnCheckout;
                  final bool isCart = widget.isFrom == "cart";
                  final bool isReBooking = widget.isFrom == "reBooking";

                  String getSubTotal() {
                    if (isCart) {
                      if (showTax) {
                        return state.cartData.subTotalWithoutTax ?? "0";
                      }
                      return state.cartData.subTotal ?? "0";
                    } else {
                      if (showTax) {
                        return state.reOrderCartData?.subTotalWithoutTax ?? "0";
                      }
                      return state.reOrderCartData?.subTotal ?? "0";
                    }
                  }

                  final double preDiscountTotal =
                      (double.tryParse(
                            isCart
                                ? state.cartData.overallAmount ?? "0"
                                : state.reOrderCartData?.overallAmount ?? "0",
                          ) ??
                          0) -
                      (selectedDeliverableOption == "atStore"
                          ? (double.tryParse(
                                  widget.isFrom == "cart"
                                      ? state.cartData.visitingCharges ?? "0"
                                      : state
                                                .reOrderCartData
                                                ?.visitingCharges ??
                                            "0",
                                ) ??
                                0)
                          : 0);
                  final double finalTotal =
                      preDiscountTotal - promoCodeDiscount;
                  final String finalTotalText = finalTotal
                      .toStringAsFixed(2)
                      .priceFormat(context);
                  final String? originalTotalText = promoCodeDiscount > 0
                      ? preDiscountTotal.toStringAsFixed(2).priceFormat(context)
                      : null;
                  final String? savedBadgeText = promoCodeDiscount > 0
                      ? '${'saved'.translate(context: context)} ${promoCodeDiscount.toStringAsFixed(2).priceFormat(context)}'
                      : null;

                  final List<Widget> rows = [
                    ChargesTile(
                      title: 'itemTotal'.translate(context: context),
                      value: getSubTotal().priceFormat(context),
                      fontSize: 14,
                    ),
                    if (showTax) ...[
                      if ((isCart
                              ? double.tryParse(
                                      state.cartData.taxValue ?? "0",
                                    ) ??
                                    0.0
                              : double.tryParse(
                                      state.reOrderCartData?.taxValue ?? "0",
                                    ) ??
                                    0.0) >
                          0) ...[
                        const CustomSizedBox(height: 8),
                        ChargesTile(
                          title: 'tax'.translate(context: context),
                          value:
                              "+ ${(isCart ? state.cartData.taxValue ?? "0" : state.reOrderCartData?.taxValue ?? "0").priceFormat(context)}",
                          fontSize: 14,
                          fontweight: FontWeight.w400,
                        ),
                      ],
                    ],
                    if ((isCart &&
                            state.cartData.fees != null &&
                            state.cartData.fees!.isNotEmpty) ||
                        (isReBooking &&
                            state.reOrderCartData?.fees != null &&
                            state.reOrderCartData!.fees!.isNotEmpty)) ...[
                      for (final fee
                          in isCart
                              ? state.cartData.fees!
                              : state.reOrderCartData!.fees!) ...[
                        const CustomSizedBox(height: 8),
                        ChargesTile(
                          title: fee.title ?? '',
                          value:
                              "+ ${(fee.amount ?? "0").priceFormat(context)}",
                          fontSize: 14,
                          fontweight: FontWeight.w400,
                        ),
                      ],
                    ],
                    if (promoCodeDiscount != 0.0) ...[
                      const CustomSizedBox(height: 8),
                      ChargesTile(
                        title: "couponDiscount".translate(context: context),
                        value:
                            '- ${promoCodeDiscount.toString().priceFormat(context)}',
                        fontSize: 14,
                        fontweight: FontWeight.w400,
                      ),
                    ],
                    if (selectedDeliverableOption != "atStore")
                      if ((isCart &&
                              state.cartData.visitingCharges != '0' &&
                              state.cartData.visitingCharges != '' &&
                              state.cartData.visitingCharges != 'null') ||
                          (isReBooking &&
                              state.reOrderCartData?.visitingCharges != '0' &&
                              state.reOrderCartData?.visitingCharges != '' &&
                              state.reOrderCartData?.visitingCharges !=
                                  'null')) ...[
                        const CustomSizedBox(height: 8),
                        ChargesTile(
                          title: 'visitingCharge'.translate(context: context),
                          value:
                              '+ ${(isCart ? state.cartData.visitingCharges : state.reOrderCartData?.visitingCharges ?? "0")?.priceFormat(context) ?? "0"}',
                          fontSize: 14,
                          fontweight: FontWeight.w400,
                        ),
                      ],
                    const CustomSizedBox(height: 8),
                    Divider(height: 1, color: context.colors.borderDefault),
                    const CustomSizedBox(height: 8),
                    ChargesTile(
                      title: 'totalAmount'.translate(context: context),
                      value: finalTotalText,
                      fontSize: 16,
                      fontweight: FontWeight.w700,
                      titleColor: context.colors.textPrimary,
                      valueColor: context.colors.textBrand,
                    ),
                  ];

                  return buildBillDetailsCard(
                    rows: rows,
                    showSavedBanner: promoCodeDiscount > 0,
                    savedAmountText:
                        '${'youSaved'.translate(context: context)} ${promoCodeDiscount.toStringAsFixed(2).priceFormat(context)} ${'onThisBooking'.translate(context: context)}',
                    finalTotalText: finalTotalText,
                    originalTotalText: originalTotalText,
                    savedBadgeText: savedBadgeText,
                  );
                }
                return const CustomSizedBox();
              },
            ),
          ],
        ],
      ),
    );
  }

  void _openWebviewPaymentGateway({required String webviewLink}) {
    ClarityService.logAction(ClarityActions.paymentGatewayRedirected, {
      ..._buildCartAnalyticsPayload(
        paymentMethod: selectedPaymentMethod,
        paymentAmount: _currentCartTotalAmount(),
      ),
      'payment_url': webviewLink,
    });
    ClarityService.setTag(
      'payment_gateway',
      selectedPaymentMethod ?? 'webview',
    );
    Navigator.pushNamed(
      context,
      webviewPaymentScreen,
      arguments: {'paymentURL': webviewLink},
    ).then((final Object? value) {
      final parameter = value as Map;
      if (parameter['paymentStatus'] == 'Completed') {
        _navigateToOrderConfirmation(isSuccess: true);
      } else if (parameter['paymentStatus'] == 'Failed') {
        _navigateToOrderConfirmation(isSuccess: false);
      }
    });
  }

  @override
  void dispose() {
    _instructionController.dispose();
    paymentButtonName.dispose();
    _isLocationUnavailableAtDoorstep.dispose();
    _cartSubscription?.cancel();
    _razorpay.clear();
    super.dispose();
  }
}
