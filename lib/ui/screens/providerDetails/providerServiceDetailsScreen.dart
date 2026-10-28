import 'package:e_demand/app/generalImports.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class ProviderServiceDetailsScreen extends StatefulWidget {
  const ProviderServiceDetailsScreen({
    super.key,
    required this.serviceDetails,
    required this.serviceId,
    required this.providerId,
    this.isProviderAvailableAtLocation,
  });

  final Services serviceDetails;
  final String serviceId;
  final String providerId;
  final String? isProviderAvailableAtLocation;

  @override
  State<ProviderServiceDetailsScreen> createState() =>
      _ProviderServiceDetailsScreenState();

  static Route route(final RouteSettings routeSettings) {
    final Map arguments = routeSettings.arguments as Map;

    return CupertinoPageRoute(
      builder: (final _) => ProviderServiceDetailsScreen(
        serviceDetails: arguments["serviceDetails"],
        serviceId: arguments["serviceId"],
        providerId: arguments["providerId"],
        isProviderAvailableAtLocation:
            arguments["isProviderAvailableAtLocation"],
      ),
    );
  }
}

class _ProviderServiceDetailsScreenState
    extends State<ProviderServiceDetailsScreen> {
  bool _isAboutDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    ClarityService.logAction(ClarityActions.serviceDetailViewed, {
      'service_id': widget.serviceId,
      'service_name': widget.serviceDetails.translatedTitle ?? '',
      'provider_id': widget.providerId,
      'duration': widget.serviceDetails.duration ?? '',
      'price': widget.serviceDetails.priceWithTax ?? '',
    });
    context.read<ServiceReviewCubit>().fetchServiceReview(
      serviceId: widget.serviceId,
      providerId: widget.providerId,
    );
    context.read<ServiceDetailsCubit>().fetchServiceDetails(
      id: widget.serviceId,
    );
  }

  Future<void> _handleShare(final String slug) async {
    final String shareURL =
        '$deepLinkDomain/service-details/$slug?lang=${HiveRepository.getCurrentLanguage()!.languageCode}';
    await UiUtils.share(context: context, shareURL, subject: "Share Service");
  }

  Widget _buildCardTitle(final String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: CustomText(
      title,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: context.colors.textPrimary,
    ),
  );

  void _openImagePreview(final List<String> images) {
    UiUtils.showBottomSheet(
      context: context,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      child: ServiceImagesList(imageList: images),
    );
  }

  Widget _buildImageGallery(final ServiceDetailsModel details) {
    final List<String> images = <String>[
      details.image ?? '',
      ...details.otherImages,
    ].where((final e) => e.isNotEmpty).toList();

    final List<String> sideThumbnails = images.length > 1
        ? images.sublist(1).take(3).toList()
        : [];

    final bool isTablet = ResponsiveHelper.isTabletDevice(context);

    Widget wrapGallery(final double aspectRatio, final Widget child) => isTablet
        ? SizedBox(height: 380, width: double.infinity, child: child)
        : AspectRatio(aspectRatio: aspectRatio, child: child);

    if (sideThumbnails.isEmpty) {
      return wrapGallery(
        352 / 336,
        CustomInkWellContainer(
          borderRadius: BorderRadius.circular(UiUtils.borderRadiusOf8),
          onTap: () => _openImagePreview(images),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(UiUtils.borderRadiusOf8),
            child: CustomCachedNetworkImage(
              networkImageUrl: images.isNotEmpty ? images.first : '',
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    return wrapGallery(
      352 / 336,
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 260,
            child: CustomInkWellContainer(
              borderRadius: BorderRadius.circular(UiUtils.borderRadiusOf8),
              onTap: () => _openImagePreview(images),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(UiUtils.borderRadiusOf8),
                child: CustomCachedNetworkImage(
                  networkImageUrl: images.first,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const CustomSizedBox(width: 12),
          Expanded(
            flex: 80,
            child: Column(
              children: List.generate(sideThumbnails.length, (final index) {
                final bool isLast = index == sideThumbnails.length - 1;
                final bool hasMore = images.length > 4 && isLast;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      top: index == 0 ? 0 : 6,
                      bottom: isLast ? 0 : 6,
                    ),
                    child: CustomInkWellContainer(
                      borderRadius: BorderRadius.circular(
                        UiUtils.borderRadiusOf8,
                      ),
                      onTap: () => _openImagePreview(images),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              UiUtils.borderRadiusOf8,
                            ),
                            child: CustomCachedNetworkImage(
                              networkImageUrl: sideThumbnails[index],
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (hasMore)
                            CustomContainer(
                              color: const Color(0x66020617),
                              borderRadius: UiUtils.borderRadiusOf8,
                              child: Center(
                                child: CustomText(
                                  'viewAll'.translate(context: context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: context.colors.textInverseLight,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow(final ServiceDetailsModel details) {
    final bool viewRating =
        double.tryParse(details.averageRating ?? '0') != null &&
        double.parse(details.averageRating!).toStringAsFixed(1) != '0.0';
    if (!viewRating) return const CustomSizedBox();
    return Row(
      children: [
        CustomSvgPicture(
          avoideResponsive: true,
          svgImage: AppAssets.icStar,
          color: context.colors.iconWarning,
          height: 16,
          width: 16,
        ),
        const CustomSizedBox(width: 4),
        CustomText(
          double.parse(details.averageRating!).toStringAsFixed(1),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.colors.textPrimary,
        ),
        Expanded(
          child: CustomText(
            ' (${details.numberOfRatings} ${details.numberOfRatings.toString().convertToInt() > 1 ? 'reviewers'.translate(context: context) : 'reviewer'.translate(context: context)})',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.colors.textTertiary,
          ),
        ),
        ServiceBookmarkIcon(
          serviceId: widget.serviceId,
          isBookmarked: details.isBookmarked == '1',
        ),
      ],
    );
  }

  Widget _buildAllowedBadge({required final String label}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CustomSvgPicture(
        avoideResponsive: true,
        svgImage: AppAssets.verified,
        height: 16,
        width: 16,
        color: context.colors.iconBrand,
      ),
      const CustomSizedBox(width: 4),
      CustomText(
        label,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: context.colors.textPrimary,
      ),
    ],
  );

  Widget _buildPriceAndActionRow(final ServiceDetailsModel details) {
    final double price = double.tryParse(details.price ?? '0') ?? 0;
    final double discountedPrice =
        double.tryParse(details.discountedPrice ?? '0') ?? 0;
    final bool hasDiscount = discountedPrice > 0 && discountedPrice < price;
    final double effectivePrice = hasDiscount ? discountedPrice : price;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  CustomText(
                    effectivePrice.toString().priceFormat(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    color: context.colors.textPrimary,
                  ),
                  if (hasDiscount)
                    CustomText(
                      price.toString().priceFormat(context),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: context.colors.textTertiary,
                      showLineThrough: true,
                      underlineOrLineColor: context.colors.textTertiary,
                    ),
                ],
              ),
              if (hasDiscount && (details.discountPercentage ?? '0') != '0')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomSvgPicture(
                      avoideResponsive: true,
                      svgImage: AppAssets.icOff,
                      height: 14,
                      width: 14,
                      color: context.colors.textSuccess,
                    ),
                    const CustomSizedBox(width: 4),
                    CustomText(
                      '${double.parse(details.discountPercentage!).toStringAsFixed(0)}% ${'off'.translate(context: context)}',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: context.colors.textSuccess,
                    ),
                  ],
                ),
            ],
          ),
        ),
        MultiBlocProvider(
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
          child: BlocConsumer<CartCubit, CartState>(
            listener: (final BuildContext context, final CartState state) {
              if (state is CartFetchSuccess) {
                try {
                  UiUtils.getVibrationEffect();
                } catch (_) {}
              }
            },
            builder: (final BuildContext context, final CartState state) =>
                AddButton(
                  height: 40,
                  padding: 8,
                  backgroundColor: context.colors.backgroundBrandSubtle,
                  serviceId: widget.serviceId,
                  providerId: widget.providerId,
                  isProviderAvailableAtLocation:
                      widget.isProviderAvailableAtLocation,
                  maximumAllowedQuantity: int.parse(
                    details.maxQuantityAllowed ?? '10',
                  ),
                  alreadyAddedQuantity:
                      widget.isProviderAvailableAtLocation == "0"
                      ? 0
                      : int.parse(
                          context.read<CartCubit>().getServiceCartQuantity(
                            serviceId: widget.serviceId,
                          ),
                        ),
                  serviceProviderName: details.provider?.companyName,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSection(final ServiceDetailsModel details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRatingRow(details),
        const CustomSizedBox(height: 8),
        CustomText(
          details.title ?? '',
          maxLines: 2,
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: context.colors.textPrimary,
        ),
        if ((details.shortDescription ?? '').isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: CustomText(
              details.shortDescription!,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: context.colors.textSecondary,
            ),
          ),
        ],
        const CustomSizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CustomSvgPicture(
              avoideResponsive: true,
              svgImage: AppAssets.users,
              height: 20,
              width: 20,
              color: context.colors.iconPrimary,
            ),
            const CustomSizedBox(width: 4),
            CustomText(
              '${details.numberOfMembersRequired} ${"person".translate(context: context)}',
              fontSize: 14,
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w400,
            ),
            const CustomSizedBox(width: 8),
            CustomContainer(
              width: 1,
              height: 10,
              color: context.colors.textPrimary,
            ),
            const CustomSizedBox(width: 8),
            CustomSvgPicture(
              avoideResponsive: true,
              svgImage: AppAssets.clock,
              height: 20,
              width: 20,
              color: context.colors.iconPrimary,
            ),
            const CustomSizedBox(width: 4),
            CustomText(
              '${details.duration} ${(details.durationType ?? 'minutes').translate(context: context)}',
              fontSize: 14,
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w400,
            ),
          ],
        ),
        if (details.atDoorstep == '1' ||
            details.atStore == '1' ||
            details.isCancellable == '1' ||
            details.payLater == '1') ...[
          const CustomSizedBox(height: 10),
          CustomContainer(
            width: double.infinity,
            color: context.colors.backgroundSecondary,
            borderRadius: UiUtils.borderRadiusOf8,
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (details.payLater == '1') ...[
                    _buildAllowedBadge(
                      label: 'payLaterAllowed'.translate(context: context),
                    ),
                    const CustomSizedBox(width: 12),
                  ],
                  if (details.atDoorstep == '1') ...[
                    _buildAllowedBadge(
                      label: 'doorstepAllowed'.translate(context: context),
                    ),
                    const CustomSizedBox(width: 12),
                  ],
                  if (details.atStore == '1') ...[
                    _buildAllowedBadge(
                      label: 'atStoreAllowed'.translate(context: context),
                    ),
                    const CustomSizedBox(width: 12),
                  ],
                  if (details.isCancellable == '1') ...[
                    _buildAllowedBadge(
                      label: 'cancellableAllowed'.translate(context: context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const CustomSizedBox(height: 12),
        _buildPriceAndActionRow(details),
      ],
    );
  }

  Widget _buildAboutServiceSection(final ServiceDetailsModel details) {
    final String description = details.description ?? '';
    if (description.isEmpty) return const CustomSizedBox();

    final String plainText = description.plainTextFromHtml;
    final bool needsTrim = plainText.length > 150;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCardTitle('aboutService'.translate(context: context)),
        if (!needsTrim) ...[
          HtmlWidget(
            description,
            textStyle: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 12,
            ),
          ),
        ] else if (_isAboutDescriptionExpanded) ...[
          HtmlWidget(
            description,
            textStyle: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 12,
            ),
          ),
          CustomInkWellContainer(
            onTap: () {
              setState(() {
                _isAboutDescriptionExpanded = false;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: CustomText(
                'readLess'.translate(context: context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.colors.textBrand,
              ),
            ),
          ),
        ] else ...[
          CustomText(
            plainText,
            maxLines: 6,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: context.colors.textSecondary,
          ),
          CustomInkWellContainer(
            onTap: () {
              setState(() {
                _isAboutDescriptionExpanded = true;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: CustomText(
                'readMore'.translate(context: context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.colors.textBrand,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInclusionSection({
    required final String title,
    required final List<String> items,
    required final bool isIncluded,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCardTitle(title),
        ...items.map(
          (final item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isIncluded ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: isIncluded
                      ? context.colors.iconBrand
                      : context.colors.iconError,
                ),
                const CustomSizedBox(width: 8),
                Expanded(
                  child: CustomText(
                    item,
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderSection(final ServiceDetailsProvider provider) {
    final bool viewRating =
        double.tryParse(provider.averageRating ?? '0') != null &&
        double.parse(provider.averageRating!).toStringAsFixed(1) != '0.0';
    final bool canChat =
        provider.preBookingChatAllowed == '1' &&
        HiveRepository.getUserToken != '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCardTitle('provider'.translate(context: context)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomContainer(
              width: 64,
              height: 64,
              borderRadius: UiUtils.borderRadiusOf12,
              color: context.colors.backgroundSecondary,
              clipBehavior: Clip.antiAlias,
              child: (provider.image ?? '').isEmpty
                  ? Icon(
                      Icons.storefront_outlined,
                      color: context.colors.iconPrimary,
                    )
                  : CustomCachedNetworkImage(
                      networkImageUrl: provider.image!,
                      height: 64,
                      width: 64,
                      fit: BoxFit.cover,
                    ),
            ),
            const CustomSizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: CustomText(
                          provider.companyName ?? '',
                          maxLines: 1,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      if (provider.isVerified == '1') ...[
                        const CustomSizedBox(width: 4),
                        CustomSvgPicture(
                          avoideResponsive: true,
                          svgImage: AppAssets.verified,
                          height: 16,
                          width: 16,
                          color: context.colors.iconBrand,
                        ),
                      ],
                    ],
                  ),
                  const CustomSizedBox(height: 4),
                  Row(
                    children: [
                      if (viewRating) ...[
                        CustomSvgPicture(
                          avoideResponsive: true,
                          svgImage: AppAssets.icStar,
                          color: context.colors.iconWarning,
                          height: 14,
                          width: 14,
                        ),
                        const CustomSizedBox(width: 4),
                        CustomText(
                          double.parse(
                            provider.averageRating!,
                          ).toStringAsFixed(1),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: context.colors.textSecondary,
                        ),
                        const CustomSizedBox(width: 8),
                        CustomContainer(
                          height: 12,
                          width: 1,
                          color: context.colors.borderStrong,
                        ),
                        const CustomSizedBox(width: 8),
                      ],
                      CustomSvgPicture(
                        avoideResponsive: true,
                        svgImage: AppAssets.mapPinArea,
                        color: context.colors.iconSecondary,
                        height: 14,
                        width: 14,
                      ),
                      const CustomSizedBox(width: 4),
                      CustomText(
                        '${double.tryParse(provider.distance ?? '0')?.ceil() ?? 0} ${context.read<SystemSettingCubit>().systemDistanceUnit}',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: context.colors.textSecondary,
                      ),
                    ],
                  ),
                  const CustomSizedBox(height: 8),
                  CustomInkWellContainer(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        providerRoute,
                        arguments: {
                          "providerId": (provider.id ?? '').isNotEmpty
                              ? provider.id
                              : widget.providerId,
                        },
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomText(
                          'exploreAllServices'.translate(context: context),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textBrand,
                        ),
                        const CustomSizedBox(width: 4),
                        CustomSvgPicture(
                          svgImage:
                              Directionality.of(context) == TextDirection.rtl
                              ? AppAssets.leftArrow
                              : AppAssets.rightArrow,
                          height: 14,
                          width: 14,
                          color: context.colors.iconBrand,
                          avoideResponsive: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (canChat) ...[
              const CustomSizedBox(width: 8),
              CustomInkWellContainer(
                borderRadius: BorderRadius.circular(UiUtils.borderRadiusOf8),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    chatMessages,
                    arguments: {
                      "chatUser": ChatUser(
                        id: provider.id ?? '',
                        name: provider.companyName ?? '',
                        translatedName: provider.companyName ?? '',
                        chatUserType: ChatUserType.providerEnquiry,
                        partnerId: provider.id ?? '',
                        unReadChats: 0,
                        profile: provider.image,
                      ),
                    },
                  );
                },
                child: CustomContainer(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(8),
                  color: context.colors.backgroundBrandSubtle,
                  borderRadius: UiUtils.borderRadiusOf8,
                  child: CustomSvgPicture(
                    svgImage: AppAssets.chat,
                    height: 16,
                    width: 16,
                    color: context.colors.iconBrand,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBrochureSection(final List<String> files) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCardTitle('brochureOrFiles'.translate(context: context)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(files.length, (final int index) {
            final fileUrl = files[index];
            final fileName = fileUrl.split("/").last;
            return CustomInkWellContainer(
              borderRadius: BorderRadius.circular(UiUtils.borderRadiusOf8),
              onTap: () {
                launchUrl(
                  Uri.parse(fileUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: CustomContainer(
                color: context.colors.backgroundSecondary,
                borderRadius: UiUtils.borderRadiusOf8,
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 12,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: CustomText(
                        fileName,
                        color: context.colors.textPrimary,
                        fontSize: 12,
                        maxLines: 1,
                      ),
                    ),
                    CustomSvgPicture(
                      svgImage: AppAssets.download,
                      height: 20,
                      width: 20,
                      color: context.colors.iconPrimary,
                      avoideResponsive: true,
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFAQSection(final List<ServiceFaQs> faqs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCardTitle('serviceFaqs'.translate(context: context)),
        Column(
          children: List.generate(
            faqs.length,
            (final int index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FaqItemCard(
                question: faqs[index].question ?? '',
                answer: faqs[index].answer ?? '',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingBreakdownRow(
    final String star,
    final int count,
    final int total,
  ) {
    final double fraction = total > 0 ? count / total : 0;
    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomText(
              star,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
            const CustomSizedBox(width: 4),
            CustomSvgPicture(
              avoideResponsive: true,
              svgImage: AppAssets.icStar,
              color: context.colors.iconWarning,
              height: 16,
              width: 16,
            ),
          ],
        ),
        const CustomSizedBox(width: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (final _, final constraints) => Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [
                CustomContainer(
                  height: 12,
                  width: double.infinity,
                  borderRadius: 24,
                  color: context.colors.backgroundSecondary,
                ),
                CustomContainer(
                  height: 12,
                  width: constraints.maxWidth * fraction,
                  borderRadius: 24,
                  color: context.colors.backgroundWarning,
                ),
              ],
            ),
          ),
        ),
        const CustomSizedBox(width: 4),
        SizedBox(
          width: 28,
          child: CustomText(
            '${(fraction * 100).round()}%',
            fontSize: 12,
            textAlign: TextAlign.end,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(final Reviews review) {
    final List images = review.images ?? [];
    final int extraImageCount = images.length - 4;
    return CustomContainer(
      width: 264,
      color: context.colors.backgroundPrimary,
      borderRadius: UiUtils.borderRadiusOf12,
      border: Border.all(color: context.colors.borderDefault, width: 1.5),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(UiUtils.borderRadiusOf8),
                child: CustomCachedNetworkImage(
                  networkImageUrl: review.profileImage ?? '',
                  height: 40,
                  width: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const CustomSizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    CustomText(
                      review.userName ?? '',
                      maxLines: 1,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: context.colors.textPrimary,
                    ),
                    CustomText(
                      UiUtils.getTimeAgo(
                        context,
                        date: DateTime.tryParse(review.ratedOn ?? ''),
                      ),
                      fontSize: 12,
                      color: context.colors.textTertiary,
                    ),
                  ],
                ),
              ),
              const CustomSizedBox(width: 8),
              CustomContainer(
                color: context.colors.backgroundWarningSubtle,
                borderRadius: UiUtils.borderRadiusOf8,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomSvgPicture(
                      avoideResponsive: true,
                      svgImage: AppAssets.icStar,
                      color: context.colors.iconWarning,
                      height: 16,
                      width: 16,
                    ),
                    const CustomSizedBox(width: 4),
                    CustomText(
                      double.parse(review.rating ?? '0').toStringAsFixed(1),
                      fontSize: 14,
                      color: context.colors.textPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          CustomContainer(height: 1, color: context.colors.borderDefault),
          CustomText(
            review.comment ?? '',
            fontSize: 12,
            maxLines: 2,
            color: context.colors.textSecondary,
          ),
          if (images.isNotEmpty)
            Row(
              children: List.generate(images.length > 4 ? 4 : images.length, (
                final int index,
              ) {
                final bool isLast =
                    index == 3 && extraImageCount > 0 && images.length > 4;
                return Padding(
                  padding: EdgeInsetsDirectional.only(end: index == 3 ? 0 : 8),
                  child: CustomInkWellContainer(
                    borderRadius: BorderRadius.circular(
                      UiUtils.borderRadiusOf8,
                    ),
                    onTap: () => isLast
                        ? UiUtils.showBottomSheet(
                            context: context,
                            enableDrag: true,
                            isScrollControlled: true,
                            useSafeArea: true,
                            child: ServiceImagesList(
                              imageList: images
                                  .map((final e) => e.toString())
                                  .toList(),
                              reviewDetails: review,
                            ),
                          )
                        : Navigator.pushNamed(
                            context,
                            imagePreview,
                            arguments: {
                              "startFrom": index,
                              "reviewDetails": review,
                              "isReviewType": true,
                              "dataURL": images,
                            },
                          ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        UiUtils.borderRadiusOf8,
                      ),
                      child: Stack(
                        children: [
                          CustomCachedNetworkImage(
                            networkImageUrl: images[index],
                            height: 32,
                            width: 32,
                            fit: BoxFit.cover,
                          ),
                          if (isLast)
                            CustomContainer(
                              height: 32,
                              width: 32,
                              color: const Color(0x66020617),
                              child: Center(
                                child: CustomText(
                                  '+$extraImageCount',
                                  fontSize: 12,
                                  color: context.colors.textInverseLight,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(
    final ServiceDetailsModel details,
    final List<Reviews> reviewList,
  ) {
    final int total = int.tryParse(details.numberOfRatings ?? '0') ?? 0;
    final Map<String, int> starCounts = {
      '5': details.ratingBreakdown['5'] ?? 0,
      '4': details.ratingBreakdown['4'] ?? 0,
      '3': details.ratingBreakdown['3'] ?? 0,
      '2': details.ratingBreakdown['2'] ?? 0,
      '1': details.ratingBreakdown['1'] ?? 0,
    };
    final double averageRating =
        double.tryParse(details.averageRating ?? '0') ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        _buildCardTitle('ratingsAndReviews'.translate(context: context)),
        CustomContainer(
          color: context.colors.backgroundPrimary,
          borderRadius: UiUtils.borderRadiusOf12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        CustomText(
                          'customerReviews'.translate(context: context),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textPrimary,
                        ),
                        CustomText(
                          '${'basedOn'.translate(context: context)} $total ${'reviews'.translate(context: context)}',
                          fontSize: 12,
                          color: context.colors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    spacing: 4,
                    children: [
                      CustomText(
                        averageRating.toStringAsFixed(1),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 4,
                        children: List.generate(5, (final int index) {
                          final bool isFilled = index < averageRating.round();
                          return CustomSvgPicture(
                            avoideResponsive: true,
                            svgImage: AppAssets.icStar,
                            color: isFilled
                                ? context.colors.iconWarning
                                : context.colors.borderDefault,
                            height: 16,
                            width: 16,
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
              CustomContainer(height: 1, color: context.colors.borderDefault),
              Column(
                spacing: 8,
                children: ['5', '4', '3', '2', '1']
                    .map(
                      (final star) => _buildRatingBreakdownRow(
                        star,
                        starCounts[star]!,
                        total,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        if (reviewList.isNotEmpty) ...[
          CustomText(
            'customerReviews'.translate(context: context),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: context.colors.textPrimary,
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: List.generate(
                  reviewList.length,
                  (final int index) => _buildReviewCard(reviewList[index]),
                ),
              ),
            ),
          ),
          CustomInkWellContainer(
            onTap: () {
              Navigator.pushNamed(
                context,
                reviewScreen,
                arguments: {
                  'providerDetails': Providers(
                    providerId: widget.providerId,
                    ratings: details.averageRating,
                    numberOfRatings: details.numberOfRatings,
                    fiveStar: starCounts['5'].toString(),
                    fourStar: starCounts['4'].toString(),
                    threeStar: starCounts['3'].toString(),
                    twoStar: starCounts['2'].toString(),
                    oneStar: starCounts['1'].toString(),
                  ),
                  'serviceId': widget.serviceId,
                },
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomText(
                  'viewAllReviews'.translate(context: context),
                  fontSize: 14,
                  color: context.colors.textBrand,
                ),
                const CustomSizedBox(width: 4),
                CustomSvgPicture(
                  svgImage: Directionality.of(context) == TextDirection.rtl
                      ? AppAssets.backArrow
                      : AppAssets.backArrowLtr,
                  height: 16,
                  width: 16,
                  color: context.colors.iconBrand,
                  avoideResponsive: true,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Services _relatedServiceToServices(final RelatedService relatedService) =>
      Services(
        id: relatedService.id,
        userId: '',
        categoryId: relatedService.categoryId,
        categoryName: relatedService.categoryName,
        partnerName: '',
        translatedPartnerName: '',
        title: relatedService.title,
        translatedTitle: relatedService.title,
        slug: relatedService.slug,
        description: relatedService.description,
        translatedDescription: relatedService.description,
        tags: '',
        imageOfTheService: relatedService.image,
        price: relatedService.price,
        discountedPrice: relatedService.discountedPrice,
        originalPriceWithTax: relatedService.price,
        taxAmount: '0',
        priceWithTax: relatedService.discountedPrice != '0'
            ? relatedService.discountedPrice
            : relatedService.price,
        numberOfMembersRequired: relatedService.numberOfMembersRequired,
        duration: relatedService.duration,
        rating: relatedService.averageRating,
        averageRating: relatedService.averageRating,
        numberOfRatings: relatedService.numberOfRatings,
        maxQuantityAllowed: '10',
        isPayLaterAllowed: '',
        status: '',
        longDescription: relatedService.description,
        translatedLongDescription: relatedService.description,
        otherImagesOfTheService: const [],
        discountPercentage: relatedService.discountPercentage,
        currencySymbol: relatedService.currencySymbol,
        durationType: relatedService.durationType,
      );

  Widget _buildSimilarServicesSection(
    final List<RelatedService> relatedServices,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        _buildCardTitle('similarServices'.translate(context: context)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: List.generate(relatedServices.length, (final int index) {
              final RelatedService relatedService = relatedServices[index];
              return ServiceCard(
                key: ValueKey(relatedService.id),
                width: context.screenWidth - 76,
                serviceId: relatedService.id ?? '',
                providerId: widget.providerId,
                title: relatedService.title,
                image: relatedService.image,
                price: relatedService.price,
                discountedPrice: relatedService.discountedPrice,
                discountPercentage: relatedService.discountPercentage,
                duration: relatedService.duration,
                durationType: relatedService.durationType,
                numberOfMembersRequired: relatedService.numberOfMembersRequired,
                averageRating: relatedService.averageRating,
                maximumAllowedQuantity: 10,
                isProviderAvailableAtLocation: '1',
                companyName: relatedService.companyName,
                isProviderVerified: relatedService.isProviderVerified == '1',
                isBookmarked: relatedService.isBookmarked == '1',
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    providerServiceDetails,
                    arguments: {
                      'serviceDetails': _relatedServiceToServices(
                        relatedService,
                      ),
                      'serviceId': relatedService.id ?? '',
                      'providerId': widget.providerId,
                    },
                  );
                },
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        CustomShimmerLoadingContainer(
          borderRadius: UiUtils.borderRadiusOf8,
          height: 200,
          width: context.screenWidth,
        ),
        CustomShimmerLoadingContainer(
          borderRadius: UiUtils.borderRadiusOf12,
          height: 220,
          width: context.screenWidth,
        ),
        CustomShimmerLoadingContainer(
          borderRadius: UiUtils.borderRadiusOf12,
          height: 100,
          width: context.screenWidth,
        ),
      ],
    ),
  );

  Widget _buildContent(final ServiceDetailsModel details) {
    final List<Widget> sections = [];

    void addSection(final Widget child) {
      if (sections.isNotEmpty) {
        sections.add(const CustomSizedBox(height: 16));
        sections.add(
          CustomSizedBox(
            height: 1,
            width: double.infinity,
            child: DashedRect(
              color: context.colors.borderStrong,
              strokeWidth: 1,
              gap: 4,
            ),
          ),
        );
        sections.add(const CustomSizedBox(height: 16));
      }
      sections.add(child);
    }

    addSection(_buildHeaderSection(details));

    if ((details.description ?? '').isNotEmpty) {
      addSection(_buildAboutServiceSection(details));
    }
    if (details.whatsIncluded.isNotEmpty) {
      addSection(
        _buildInclusionSection(
          title: "includedInService".translate(context: context),
          items: details.whatsIncluded,
          isIncluded: true,
        ),
      );
    }
    if (details.whatsExcluded.isNotEmpty) {
      addSection(
        _buildInclusionSection(
          title: "excludedInService".translate(context: context),
          items: details.whatsExcluded,
          isIncluded: false,
        ),
      );
    }
    if (details.provider != null) {
      addSection(_buildProviderSection(details.provider!));
    }
    if (details.files.isNotEmpty) {
      addSection(_buildBrochureSection(details.files));
    }
    if (details.faqs.isNotEmpty) {
      addSection(_buildFAQSection(details.faqs));
    }

    final ServiceReviewState reviewState = context
        .watch<ServiceReviewCubit>()
        .state;
    if (reviewState is ServiceReviewFetchSuccess &&
        reviewState.reviewList.isNotEmpty) {
      addSection(_buildReviewSection(details, reviewState.reviewList));
    } else if (reviewState is ServiceReviewInitial ||
        reviewState is ServiceReviewFetchInProgress) {
      addSection(
        CustomShimmerLoadingContainer(
          borderRadius: UiUtils.borderRadiusOf12,
          height: 120,
          width: context.screenWidth,
        ),
      );
    }

    if (details.relatedServices.isNotEmpty) {
      addSection(_buildSimilarServicesSection(details.relatedServices));
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          _buildImageGallery(details),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sections,
          ),
          const CustomContainer(height: 70),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedSafeArea(
      isAnnotated: true,
      child: Scaffold(
        backgroundColor: context.colors.backgroundPrimary,
        appBar: UiUtils.getSimpleAppBar(
          context: context,
          title: 'serviceDetails'.translate(context: context),
          actions: [
            BlocBuilder<ServiceDetailsCubit, ServiceDetailsState>(
              builder: (context, state) {
                if (state is! ServiceDetailsFetchSuccess) {
                  return const CustomSizedBox();
                }
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: CustomInkWellContainer(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _handleShare(state.serviceDetails.slug ?? ''),
                    child: CustomContainer(
                      color: context.colors.backgroundPrimary,
                      shape: BoxShape.circle,
                      padding: const EdgeInsets.all(8),
                      child: CustomSvgPicture(
                        svgImage: AppAssets.drShare,
                        height: 24,
                        width: 24,
                        color: context.colors.iconPrimary,
                        avoideResponsive: true,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            BlocBuilder<ServiceDetailsCubit, ServiceDetailsState>(
              builder: (context, state) {
                if (state is ServiceDetailsFetchFailure) {
                  return ErrorContainer(
                    errorMessage: state.errorMessage,
                    onTapRetry: () {
                      context.read<ServiceDetailsCubit>().fetchServiceDetails(
                        id: widget.serviceId,
                      );
                    },
                  );
                }
                if (state is ServiceDetailsFetchSuccess) {
                  return _buildContent(state.serviceDetails);
                }
                return _buildShimmerLoading();
              },
            ),
            if ((context.watch<CartCubit>().state is CartFetchSuccess) &&
                (context.watch<CartCubit>().state as CartFetchSuccess)
                        .cartData
                        .providerId ==
                    widget.providerId)
              const Align(
                alignment: Alignment.bottomCenter,
                child: AddToCartComtainer(),
              ),
            if (context.watch<CartCubit>().state is CartFetchSuccess &&
                ((context.watch<CartCubit>().state as CartFetchSuccess)
                            .cartData
                            .cartDetails ??
                        [])
                    .isNotEmpty &&
                ((context.watch<CartCubit>().state as CartFetchSuccess)
                        .cartData
                        .providerId !=
                    widget.providerId)) ...[
              Align(
                alignment: Alignment.bottomCenter,
                child: CartSubDetailsContainer(providerID: widget.providerId),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
