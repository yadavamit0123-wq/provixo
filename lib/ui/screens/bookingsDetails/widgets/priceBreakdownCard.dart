import 'package:e_demand/app/generalImports.dart';
import 'package:flutter/material.dart';

class PriceBreakdownCard extends StatefulWidget {
  const PriceBreakdownCard({super.key, required this.bookingDetails});

  final BookingDetailModel bookingDetails;

  @override
  State<PriceBreakdownCard> createState() => _PriceBreakdownCardState();
}

class _PriceBreakdownCardState extends State<PriceBreakdownCard> {
  bool _expanded = false;

  bool _isPositive(final String? value) {
    if (value == null || value.isEmpty) return false;
    return (double.tryParse(value.replaceAll(',', '')) ?? 0) > 0;
  }

  String _paymentIcon(final String method) {
    switch (method.toLowerCase()) {
      case 'stripe':
        return AppAssets.stripe;
      case 'razorpay':
        return AppAssets.razorpay;
      case 'paystack':
        return AppAssets.paystack;
      case 'paypal':
        return AppAssets.paypal;
      case 'flutterwave':
        return AppAssets.flutterwave;
      case 'cashfree':
        return AppAssets.cashfree;
      case 'cod':
      default:
        return AppAssets.cod;
    }
  }

  ({Color background, Color text}) _statusColors(
    final BuildContext context,
    final String status,
  ) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'completed':
      case '1':
        return (
          background: context.colors.backgroundSuccessSubtle,
          text: context.colors.textSuccess,
        );
      case 'failed':
      case '2':
        return (
          background: context.colors.backgroundErrorSubtle,
          text: context.colors.textError,
        );
      default:
        return (
          background: context.colors.backgroundWarningSubtle,
          text: context.colors.textWarning,
        );
    }
  }

  double _sumAmounts(final Iterable<String?> values) => values.fold(
    0.0,
    (final total, final value) =>
        total + (double.tryParse((value ?? '0').replaceAll(',', '')) ?? 0.0),
  );

  Widget _buildLineItem(
    final BuildContext context, {
    required final String label,
    required final String amount,
    final bool emphasize = false,
    final Color? amountColor,
    final FontWeight? amountFontWeight,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: CustomText(
            label,
            fontSize: emphasize ? 14 : 12,
            fontWeight: emphasize ? FontWeight.w500 : FontWeight.w400,
            color: emphasize
                ? context.colors.textPrimary
                : context.colors.textSecondary,
          ),
        ),
        CustomText(
          amount,
          fontSize: emphasize ? 14 : 12,
          fontWeight:
              amountFontWeight ??
              (emphasize ? FontWeight.w500 : FontWeight.w400),
          color: amountColor ?? context.colors.textPrimary,
        ),
      ],
    ),
  );

  @override
  Widget build(final BuildContext context) {
    final booking = widget.bookingDetails;
    final paymentStatus = booking.paymentStatus ?? '';
    final statusColors = _statusColors(context, paymentStatus);

    return CustomContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: context.colors.surfacePrimary,
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomInkWellContainer(
            showRippleEffect: false,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _expanded
                      ? CustomText(
                          'billDetails'.translate(context: context),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textPrimary,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CustomText(
                              '${'totalAmount'.translate(context: context)} : ${(booking.finalTotal ?? '0').priceFormat(context)}',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: context.colors.textPrimary,
                            ),
                            const CustomSizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: CustomText(
                                    '${'paymentMode'.translate(context: context)} : ${booking.paymentMethod ?? ''}',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: context.colors.textSecondary,
                                    maxLines: 1,
                                  ),
                                ),
                                const CustomSizedBox(width: 8),
                                CustomContainer(
                                  padding: const EdgeInsets.all(4),
                                  color: statusColors.background,
                                  borderRadius: 4,
                                  child: CustomText(
                                    paymentStatus.isEmpty
                                        ? 'pending'.translate(context: context)
                                        : paymentStatus.translate(
                                            context: context,
                                          ),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: statusColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                CustomContainer(
                  padding: const EdgeInsets.all(8),
                  color: context.colors.backgroundSecondary,
                  borderRadius: 24,
                  child: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: context.colors.iconPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const CustomSizedBox(height: 12),
            CustomSizedBox(
              height: 1,
              width: double.infinity,
              child: DashedRect(
                color: context.colors.borderDefault,
                strokeWidth: 1,
                gap: 4,
              ),
            ),
            const CustomSizedBox(height: 12),
            if ((booking.additionalCharges ?? []).isNotEmpty) ...[
              ...booking.additionalCharges!.map(
                (charge) => _buildLineItem(
                  context,
                  label: charge.name ?? '',
                  amount: "+ ${(charge.charge ?? '0').priceFormat(context)}",
                ),
              ),
              // for (final charge in booking.additionalCharges ?? [])
              //   _buildLineItem(
              //     context,
              //     label: charge.name ?? '',
              //     amount: '+ ${(charge.charge ?? '0').priceFormat(context)}',
              //   ),
              _buildLineItem(
                context,
                label: 'totalAdditionalCharges'.translate(context: context),
                amount: _sumAmounts(
                  booking.additionalCharges!.map((final c) => c.charge),
                ).toString().priceFormat(context),
                emphasize: true,
              ),
              const CustomSizedBox(height: 8),
              CustomSizedBox(
                height: 1,
                width: double.infinity,
                child: DashedRect(
                  color: context.colors.borderDefault,
                  strokeWidth: 1,
                  gap: 4,
                ),
              ),
              const CustomSizedBox(height: 8),
            ],
            _buildLineItem(
              context,
              label: 'subTotal'.translate(context: context),
              amount: (booking.baseTotal ?? '0').priceFormat(context),
            ),
            if (_isPositive(booking.tax?.taxAmount))
              _buildLineItem(
                context,
                label: 'tax'.translate(context: context),
                // Tax already folded into base_total when included — showing
                // it with a "+" would make the visible lines double-count it.
                amount: booking.tax!.isIncluded
                    ? (booking.tax?.taxAmount ?? '0').priceFormat(context)
                    : '+ ${(booking.tax?.taxAmount ?? '0').priceFormat(context)}',
              ),
            if (booking.bookingType != 'at_store' &&
                _isPositive(booking.visitingCharges))
              _buildLineItem(
                context,
                label: 'visitingCharge'.translate(context: context),
                amount:
                    '+ ${(booking.visitingCharges ?? '0').priceFormat(context)}',
              ),
            if ((booking.promoCode ?? '').isNotEmpty &&
                _isPositive(booking.promoDiscount))
              _buildLineItem(
                context,
                label:
                    '${'promoCode'.translate(context: context)} (${booking.promoCode})',
                amount:
                    '- ${(booking.promoDiscount ?? '0').priceFormat(context)}',
              ),
            if (booking.fees != null && booking.fees!.isNotEmpty)
              ...booking.fees!.map(
                (fee) => _buildLineItem(
                  context,
                  label: fee.title ?? '',
                  amount:
                      "+ ${(fee.calculatedAmount ?? '0').priceFormat(context)}",
                ),
              ),
            const CustomSizedBox(height: 8),
            CustomSizedBox(
              height: 1,
              width: double.infinity,
              child: DashedRect(
                color: context.colors.borderDefault,
                strokeWidth: 1,
                gap: 4,
              ),
            ),
            const CustomSizedBox(height: 8),
            _buildLineItem(
              context,
              label: 'totalPaid'.translate(context: context),
              amount: (booking.finalTotal ?? '0').priceFormat(context),
              emphasize: true,
              amountColor: context.colors.textBrand,
              amountFontWeight: FontWeight.w600,
            ),
            const CustomSizedBox(height: 12),
            CustomContainer(
              padding: const EdgeInsets.all(8),
              color: context.colors.backgroundSecondary,
              borderRadius: 8,
              child: Row(
                children: [
                  CustomSvgPicture(
                    svgImage: _paymentIcon(booking.paymentMethod ?? ''),
                    height: 36,
                    width: 36,
                    avoideResponsive: true,
                  ),
                  const CustomSizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomText(
                          'paymentWith'.translate(context: context),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: context.colors.textTertiary,
                        ),
                        const CustomSizedBox(height: 4),
                        CustomText(
                          booking.paymentMethod ?? '',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textPrimary,
                        ),
                      ],
                    ),
                  ),
                  CustomContainer(
                    padding: const EdgeInsets.all(8),
                    color: statusColors.background,
                    borderRadius: 8,
                    child: CustomText(
                      paymentStatus.isEmpty
                          ? 'pending'.translate(context: context)
                          : paymentStatus.translate(context: context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: statusColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
