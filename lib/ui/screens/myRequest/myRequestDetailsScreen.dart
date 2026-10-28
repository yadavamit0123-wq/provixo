import 'package:e_demand/app/generalImports.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyRequestDetailsScreen extends StatefulWidget {
  const MyRequestDetailsScreen({
    final Key? key,
    required this.customJobRequestId,
    required this.status,
    this.minPrice,
    this.maxPrice,
    this.bookingId,
    this.initialTabIndex = 0,
  }) : super(key: key);

  final String customJobRequestId;
  final String status;
  final String? minPrice;
  final String? maxPrice;
  final String? bookingId;
  final int initialTabIndex;

  static Route route(final RouteSettings settings) {
    final arguments = settings.arguments as Map;
    return CupertinoPageRoute(
      builder: (final context) => MyRequestDetailsScreen(
        customJobRequestId: arguments['customJobRequestId'],
        status: arguments['status'],
        minPrice: arguments['minPrice'],
        maxPrice: arguments['maxPrice'],
        bookingId: arguments['bookingId'],
        initialTabIndex: arguments['initialTabIndex'] ?? 0,
      ),
    );
  }

  @override
  State<MyRequestDetailsScreen> createState() => _MyRequestDetailsScreenState();
}

class _MyRequestDetailsScreenState extends State<MyRequestDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final Map<String, bool> _downloadingMap = {};
  Timer? _countdownTimer;
  Duration? _timeLeft;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    fetchServiceDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void fetchServiceDetails() {
    context.read<MyRequestDetailsCubit>().fetchRequestDetails(
      customJobRequestId: widget.customJobRequestId,
    );
  }

  void _startCountdown(final CustomJob job) {
    _countdownTimer?.cancel();
    final endDt = _parseDateTime(job.endDateTime ?? '');
    if (endDt == null) return;
    _tick(endDt);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _tick(endDt);
    });
  }

  void _tick(final DateTime expiry) {
    final remaining = expiry.difference(DateTime.now());
    if (mounted)
      setState(
        () => _timeLeft = remaining.isNegative ? Duration.zero : remaining,
      );
  }

  DateTime? _parseDateTime(final String raw) {
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  String _formatCountdown(final Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s Hrs Left';
  }

  ({Color background, Color text}) _statusColors(
    final BuildContext context,
    final String status,
  ) {
    switch (status) {
      case 'booked':
        return (
          background: context.colors.backgroundSuccessSubtle,
          text: context.colors.textSuccess,
        );
      case 'cancelled':
      case 'expiry':
        return (
          background: context.colors.backgroundErrorSubtle,
          text: context.colors.textError,
        );
      case 'pending':
      default:
        return (
          background: context.colors.backgroundWarningSubtle,
          text: context.colors.textWarning,
        );
    }
  }

  String _statusLabel(final BuildContext context, final String status) {
    switch (status) {
      case 'booked':
        return 'booked'.translate(context: context);
      case 'cancelled':
        return 'cancelled'.translate(context: context);
      case 'expiry':
        return 'expiry'.translate(context: context);
      case 'pending':
      default:
        return 'requested'.translate(context: context);
    }
  }

  bool _canCancel(final String? status) =>
      status != 'cancelled' && status != 'booked' && status != 'expiry';

  String _formatDateTimeFull(final String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd/MM/yyyy - hh:mm a').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _formatDateOnly(final String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Widget _sectionDivider() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const CustomSizedBox(height: 12),
      Divider(height: 1, color: context.colors.borderDefault),
      const CustomSizedBox(height: 12),
    ],
  );

  Widget _buildCard({
    required final String title,
    required final Widget child,
  }) => CustomContainer(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    color: context.colors.surfacePrimary,
    borderRadius: 8,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomText(
          title,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: context.colors.textPrimary,
        ),
        _sectionDivider(),
        child,
      ],
    ),
  );

  Widget _buildIconRow({
    required final String svgIcon,
    required final String label,
    required final String value,
    final CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) => Row(
    crossAxisAlignment: crossAxisAlignment,
    children: [
      CustomContainer(
        padding: const EdgeInsets.all(8),
        color: context.colors.backgroundSecondary,
        borderRadius: 8,
        child: CustomSvgPicture(
          svgImage: svgIcon,
          height: 20,
          width: 20,
          color: context.colors.iconPrimary,
          avoideResponsive: true,
        ),
      ),
      const CustomSizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomText(
              label,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: context.colors.textSecondary,
            ),
            const CustomSizedBox(height: 4),
            CustomText(
              value,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: context.colors.textPrimary,
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildSummaryCard(final BuildContext context, final CustomJob job) {
    final statusColors = _statusColors(context, job.status ?? '');
    final bool hasBudget =
        (widget.minPrice?.isNotEmpty ?? false) &&
        (widget.maxPrice?.isNotEmpty ?? false);
    final endDt = _parseDateTime(job.endDateTime ?? '');
    final bool isPending = job.status == 'pending';

    return CustomContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: context.colors.surfacePrimary,
      borderRadius: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomText(
                      job.title ?? '',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textPrimary,
                    ),
                    const CustomSizedBox(height: 4),
                    CustomText(
                      job.categoryName ?? '',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textBrand,
                    ),
                  ],
                ),
              ),
              const CustomSizedBox(width: 12),
              CustomContainer(
                padding: const EdgeInsets.all(8),
                color: statusColors.background,
                borderRadius: 8,
                child: CustomText(
                  _statusLabel(context, job.status ?? ''),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: statusColors.text,
                ),
              ),
            ],
          ),
          if (hasBudget) ...[
            const CustomSizedBox(height: 12),
            CustomContainer(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: context.colors.backgroundSecondary,
              borderRadius: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    'budgetRange'.translate(context: context),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: context.colors.textTertiary,
                  ),
                  const CustomSizedBox(height: 4),
                  CustomText(
                    widget.minPrice == widget.maxPrice
                        ? widget.minPrice!.priceFormat(context)
                        : '${widget.minPrice!.priceFormat(context)} - ${widget.maxPrice!.priceFormat(context)}',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textPrimary,
                  ),
                ],
              ),
            ),
          ],
          if (isPending && endDt != null) ...[
            const CustomSizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(
                        'expiresOn'.translate(context: context),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: context.colors.textTertiary,
                      ),
                      const CustomSizedBox(height: 4),
                      CustomText(
                        _formatDateOnly(job.endDateTime),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textPrimary,
                      ),
                    ],
                  ),
                ),
                if (_timeLeft != null && _timeLeft! > Duration.zero)
                  CustomContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    color: context.colors.backgroundInfoSubtle,
                    borderRadius: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomSvgPicture(
                          svgImage: AppAssets.clock,
                          height: 16,
                          width: 16,
                          color: context.colors.iconInfo,
                          avoideResponsive: true,
                        ),
                        const CustomSizedBox(width: 4),
                        CustomText(
                          _formatCountdown(_timeLeft!),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textInfo,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const CustomSizedBox(height: 8),
            CustomText(
              'chooseProviderBeforeExpiry'.translate(context: context),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: context.colors.textError,
            ),
          ],
          if (job.status == 'cancelled' &&
              (job.cancelReason ?? '').isNotEmpty) ...[
            const CustomSizedBox(height: 12),
            CustomSizedBox(
              height: 1,
              width: double.infinity,
              child: DashedRect(
                color: context.colors.borderMuted,
                strokeWidth: 1,
                gap: 4,
              ),
            ),
            const CustomSizedBox(height: 12),
            CustomContainer(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: context.colors.backgroundErrorSubtle,
              borderRadius: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomText(
                    'cancellationReason'.translate(context: context),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: context.colors.textSecondary,
                  ),
                  const CustomSizedBox(height: 4),
                  CustomText(
                    job.cancelReason ?? '',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textPrimary,
                  ),
                ],
              ),
            ),
          ],
          if (job.status == 'expiry') ...[
            const CustomSizedBox(height: 12),
            CustomSizedBox(
              height: 1,
              width: double.infinity,
              child: DashedRect(
                color: context.colors.borderMuted,
                strokeWidth: 1,
                gap: 4,
              ),
            ),
            const CustomSizedBox(height: 12),
            CustomContainer(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: context.colors.backgroundErrorSubtle,
              borderRadius: 8,
              child: CustomText(
                'requestExpiredMessage'.translate(context: context),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: context.colors.textError,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestDetailsCard(
    final BuildContext context,
    final CustomJob job,
  ) {
    final phone = [
      job.countryCode,
      job.phone,
    ].where((v) => v != null && v.isNotEmpty).join(' ');

    return _buildCard(
      title: 'viewRequestDetails'.translate(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomText(
            'description'.translate(context: context),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.colors.textPrimary,
          ),
          const CustomSizedBox(height: 8),
          CustomReadMoreTextContainer(
            text: job.description ?? '',
            trimLines: 5,
            textStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: context.colors.textSecondary,
            ),
          ),
          if ((job.description ?? '').isNotEmpty) _sectionDivider(),
          if (phone.isNotEmpty) ...[
            _buildIconRow(
              svgIcon: AppAssets.phoneCall,
              label: 'phoneNumber'.translate(context: context),
              value: phone,
            ),
            _sectionDivider(),
          ],
          _buildIconRow(
            svgIcon: AppAssets.calendar,
            label: 'startAt'.translate(context: context),
            value: _formatDateTimeFull(job.startDateTime),
          ),
          _sectionDivider(),
          _buildIconRow(
            svgIcon: AppAssets.calendar,
            label: 'endAt'.translate(context: context),
            value: _formatDateTimeFull(job.endDateTime),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentCard(final BuildContext context, final CustomJob job) {
    final attachments = job.attachments;
    if (attachments == null) return const SizedBox.shrink();

    final mediaUrls = [...attachments.images, ...attachments.videos];
    final docUrls = attachments.others;

    if (mediaUrls.isEmpty && docUrls.isEmpty) return const SizedBox.shrink();

    return _buildCard(
      title: 'attachment'.translate(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mediaUrls.isNotEmpty) ...[
            _buildMediaThumbnails(context, mediaUrls),
            if (docUrls.isNotEmpty) const CustomSizedBox(height: 12),
          ],
          ...docUrls.map(
            (url) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildFileRow(context, url),
            ),
          ),
          ...attachments.videos.map(
            (url) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildFileRow(context, url, isVideo: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaThumbnails(
    final BuildContext context,
    final List<String> urls,
  ) {
    const maxVisible = 4;
    final visibleUrls = urls.take(maxVisible).toList();
    final extra = urls.length - maxVisible;

    return Row(
      children: [
        ...visibleUrls.asMap().entries.map((entry) {
          final idx = entry.key;
          final url = entry.value;
          final isLast = idx == maxVisible - 1 && extra > 0;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CustomInkWellContainer(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.pushNamed(
                context,
                imagePreview,
                arguments: {
                  'dataURL': urls,
                  'startFrom': idx,
                  'isReviewType': false,
                  'reviewDetails': null,
                },
              ),
              child: CustomContainer(
                width: 48,
                height: 48,
                borderRadius: 8,
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomCachedNetworkImage(
                      networkImageUrl: url,
                      fit: BoxFit.cover,
                      height: 48,
                      width: 48,
                    ),
                    if (isLast)
                      Container(
                        color: Colors.black.withValues(alpha: 0.4),
                        alignment: Alignment.center,
                        child: CustomText(
                          '+$extra',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textInverseLight,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFileRow(
    final BuildContext context,
    final String url, {
    final bool isVideo = false,
  }) {
    final fileName = Uri.parse(url).pathSegments.last;
    final isDownloading = _downloadingMap[url] ?? false;
    return CustomInkWellContainer(
      borderRadius: BorderRadius.circular(8),
      onTap: isDownloading
          ? null
          : () async {
              setState(() => _downloadingMap[url] = true);
              await UiUtils.downloadOrShareFile(
                url: url,
                customFileName: fileName,
                isDownload: true,
              );
              if (mounted) setState(() => _downloadingMap[url] = false);
            },
      child: CustomContainer(
        padding: const EdgeInsets.all(12),
        color: context.colors.surfacePrimary,
        borderRadius: 8,
        border: Border.all(color: context.colors.borderDefault, width: 1.5),
        child: Row(
          children: [
            CustomContainer(
              padding: const EdgeInsets.all(8),
              color: context.colors.backgroundSecondary,
              borderRadius: 8,
              child: CustomSvgPicture(
                svgImage: isVideo ? AppAssets.play : AppAssets.fileText,
                height: 16,
                width: 16,
                color: context.colors.iconSecondary,
                avoideResponsive: true,
              ),
            ),
            const CustomSizedBox(width: 8),
            Expanded(
              child: CustomText(
                fileName,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                maxLines: 1,
                color: context.colors.textPrimary,
              ),
            ),
            const CustomSizedBox(width: 8),
            isDownloading
                ? CustomCircularProgressIndicator(
                    color: context.colors.iconBrand,
                    widthAndHeight: 20,
                  )
                : CustomSvgPicture(
                    svgImage: AppAssets.download,
                    height: 24,
                    width: 24,
                    color: context.colors.iconSecondary,
                    avoideResponsive: true,
                  ),
          ],
        ),
      ),
    );
  }

  void _openSortBottomSheet(
    final BuildContext context,
    final String? currentSortBy,
  ) {
    SortByBottomSheet.show(
      context,
      currentSortBy: currentSortBy,
      onSelected: (final sortBy) {
        context.read<MyRequestDetailsCubit>().sortBidders(
          customJobRequestId: widget.customJobRequestId,
          sortBy: sortBy,
        );
      },
    );
  }

  Widget _buildProviderBidTab(
    final BuildContext context,
    final List<BidProvider> bidders,
    final String currentStatus, {
    final String? selectedSortBy,
    final bool isSorting = false,
  }) {
    if (bidders.isEmpty && !isSorting) {
      return Center(
        child: NoDataFoundWidget(
          titleKey: 'noOneHasBidYet'.translate(context: context),
        ),
      );
    }

    return Column(
      children: [
        CustomContainer(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: CustomText(
                  'availableProviderBid'.translate(context: context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textPrimary,
                ),
              ),
              CustomInkWellContainer(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openSortBottomSheet(context, selectedSortBy),
                child: CustomContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  color: context.colors.surfacePrimary,
                  borderRadius: 8,
                  border: Border.all(
                    color: context.colors.borderDefault,
                    width: 1.5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomText(
                        'sortBy'.translate(context: context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textPrimary,
                      ),
                      const CustomSizedBox(width: 4),
                      CustomSvgPicture(
                        svgImage: AppAssets.downArrow,
                        height: 16,
                        width: 16,
                        color: context.colors.textPrimary,
                        avoideResponsive: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: isSorting
              ? const Center(child: CustomCircularProgressIndicator())
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  separatorBuilder: (_, __) => const CustomSizedBox(height: 14),
                  itemCount: bidders.length,
                  itemBuilder: (ctx, idx) =>
                      _buildBidderCard(ctx, bidders[idx], currentStatus),
                ),
        ),
      ],
    );
  }

  void _openChatWithBidder(
    final BuildContext context,
    final BidProvider bidder,
    final String currentStatus,
  ) {
    Navigator.pushNamed(
      context,
      chatMessages,
      arguments: {
        "chatUser": ChatUser(
          partnerId: bidder.providerId.toString(),
          name: bidder.companyName,
          translatedName: bidder.translatedProviderName ?? bidder.companyName,
          chatUserType: currentStatus == 'booked'
              ? ChatUserType.providerBooking
              : ChatUserType.providerEnquiry,
          unReadChats: 0,
          profile: bidder.providerImage,
          id: bidder.providerId.toString(),
          bookingId: widget.customJobRequestId,
          bookingStatus: currentStatus,
        ),
      },
    );
  }

  String _formatBidDate(final String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Widget _buildBidderCard(
    final BuildContext context,
    final BidProvider bidder,
    final String currentStatus,
  ) {
    final bool canBook = _canCancel(currentStatus);

    return CustomContainer(
      padding: const EdgeInsets.all(12),
      color: context.colors.surfacePrimary,
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5.76),
                child: CustomCachedNetworkImage(
                  networkImageUrl: bidder.providerImage ?? '',
                  height: 36,
                  width: 36,
                  fit: BoxFit.cover,
                  avoideResponsive: true,
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
                        Flexible(
                          child: CustomText(
                            bidder.companyName,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: context.colors.textPrimary,
                            maxLines: 1,
                          ),
                        ),
                        if (bidder.isVerified) ...[
                          const CustomSizedBox(width: 8),
                          CustomSvgPicture(
                            svgImage: AppAssets.verified,
                            height: 16,
                            width: 16,
                            color: context.colors.iconBrand,
                            avoideResponsive: true,
                          ),
                        ],
                      ],
                    ),
                    const CustomSizedBox(height: 4),
                    Row(
                      children: [
                        CustomSvgPicture(
                          svgImage: AppAssets.icStar,
                          height: 16,
                          width: 16,
                          color: context.colors.iconWarning,
                          avoideResponsive: true,
                        ),
                        const CustomSizedBox(width: 4),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${bidder.averageRating} ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              TextSpan(
                                text: '(${bidder.totalRatings})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFFBFBFBF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (bidder.distance != null) ...[
                          const CustomSizedBox(width: 8),
                          CustomText(
                            '|',
                            fontSize: 12,
                            color: context.colors.textPrimary,
                          ),
                          const CustomSizedBox(width: 8),
                          CustomSvgPicture(
                            svgImage: AppAssets.mapPinArea,
                            height: 16,
                            width: 16,
                            color: context.colors.iconPrimary,
                            avoideResponsive: true,
                          ),
                          const CustomSizedBox(width: 4),
                          CustomText(
                            '${bidder.distance!.toStringAsFixed(1)} ${context.read<SystemSettingCubit>().systemDistanceUnit}',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: context.colors.textPrimary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const CustomSizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentStatus == 'booked'
                      ? bidder.isPostBookingChatAllowed
                      : bidder.isPreBookingChatAllowed) ...[
                    CustomInkWellContainer(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () =>
                          _openChatWithBidder(context, bidder, currentStatus),
                      child: CustomContainer(
                        padding: const EdgeInsets.all(8),
                        color: context.colors.backgroundBrandSubtle,
                        borderRadius: 8,
                        child: CustomSvgPicture(
                          svgImage: AppAssets.chat,
                          height: 20,
                          width: 20,
                          color: context.colors.iconBrand,
                          avoideResponsive: true,
                        ),
                      ),
                    ),
                    const CustomSizedBox(width: 8),
                  ],
                  CustomInkWellContainer(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.pushNamed(
                      context,
                      providerRoute,
                      arguments: {
                        'providerId': bidder.providerId.toString(),
                        'type': ProviderDetailsParamType.id,
                      },
                    ),
                    child: CustomContainer(
                      padding: const EdgeInsets.all(8),
                      color: context.colors.backgroundSecondary,
                      borderRadius: 8,
                      child: CustomSvgPicture(
                        svgImage:
                            Directionality.of(context).toString().contains(
                              TextDirection.RTL.value.toLowerCase(),
                            )
                            ? AppAssets.backArrow
                            : AppAssets.backArrowLtr,
                        height: 20,
                        width: 20,
                        color: context.colors.iconSecondary,
                        avoideResponsive: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

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

          Row(
            children: [
              CustomContainer(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                color: context.colors.backgroundBrandSubtle,
                borderRadius: 8,
                child: CustomText(
                  bidder.counterPrice.priceFormat(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: context.colors.textPrimary,
                ),
              ),
              const CustomSizedBox(width: 8),
              CustomContainer(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: context.colors.backgroundBrandSubtle,
                borderRadius: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomSvgPicture(
                      svgImage: AppAssets.clock,
                      height: 16,
                      width: 16,
                      color: context.colors.iconPrimary,
                      avoideResponsive: true,
                    ),
                    const CustomSizedBox(width: 4),
                    CustomText(
                      '${bidder.duration} ${'min'.translate(context: context)}',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: context.colors.textPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (bidder.message.isNotEmpty) ...[
            const CustomSizedBox(height: 12),
            CustomContainer(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: context.colors.backgroundSecondary,
              borderRadius: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomText(
                    'providerMessage'.translate(context: context),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: context.colors.textPrimary,
                  ),
                  const CustomSizedBox(height: 4),
                  CustomText(
                    bidder.message,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: context.colors.textSecondary,
                  ),
                ],
              ),
            ),
          ],

          const CustomSizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomText(
                      (currentStatus == 'booked' ? 'bookedOn' : 'bidPlacedOn')
                          .translate(context: context),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: context.colors.textSecondary,
                    ),
                    const CustomSizedBox(height: 4),
                    CustomText(
                      _formatBidDate(
                        currentStatus == 'booked'
                            ? bidder.bookedOn
                            : bidder.bidDate,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: context.colors.textPrimary,
                    ),
                  ],
                ),
              ),
              if (canBook)
                CustomInkWellContainer(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.pushNamed(
                    context,
                    scheduleScreenRoute,
                    arguments: {
                      'isFrom': 'customJobRequest',
                      'providerName':
                          bidder.translatedProviderName ?? bidder.companyName,
                      'providerId': bidder.providerId.toString(),
                      'companyName': bidder.companyName,
                      'providerAdvanceBookingDays': bidder.advanceBookingDays,
                      'customJobRequestId':
                          bidder.customJobRequestId ??
                          widget.customJobRequestId,
                      'bidder': bidder,
                    },
                  ),
                  child: CustomContainer(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    color: context.colors.backgroundBrand,
                    borderRadius: 8,
                    child: CustomText(
                      'bookProvider'.translate(context: context),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: context.colors.textInverseLight,
                    ),
                  ),
                )
              else if (currentStatus == 'booked')
                CustomContainer(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  color: context.colors.backgroundSuccess,
                  borderRadius: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomSvgPicture(
                        svgImage: AppAssets.checkCircleFill,
                        height: 20,
                        width: 20,
                        color: context.colors.iconInverseLight,
                        avoideResponsive: true,
                      ),
                      const CustomSizedBox(width: 4),
                      CustomText(
                        'booked'.translate(context: context),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: context.colors.textInverseLight,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton(
    final BuildContext context,
    final CustomJob job,
  ) => BlocListener<CancelCustomJobRequestCubit, CancelCustomJobRequestState>(
    listener: (_, state) {
      if (state is CancelCustomJobRequestSuccess) {
        UiUtils.showMessage(
          context,
          state.response,
          ToastificationType.success,
        );
        context.read<MyRequestDetailsCubit>().markCancelled(
          cancelReason: state.cancelReasonText,
        );
        context.read<MyRequestListCubit>().updateRequestStatusLocally(
          requestId: widget.customJobRequestId,
          status: 'cancelled',
        );
      } else if (state is CancelCustomJobRequestFailure) {
        UiUtils.showMessage(
          context,
          state.errorMessage.translate(context: context),
          ToastificationType.error,
        );
      }
    },
    child:
        BlocBuilder<CancelCustomJobRequestCubit, CancelCustomJobRequestState>(
          builder: (ctx, cancelState) {
            final isLoading = cancelState is CancelCustomJobRequestInProgress;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.backgroundPrimary,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                    color: context.colors.overlayFooterShadow,
                  ),
                ],
              ),
              child: CustomContainer(
                height: 48,
                borderRadius: 12,
                color: context.colors.backgroundErrorSubtle,
                border: Border.all(color: context.colors.borderError, width: 1),
                child: CustomInkWellContainer(
                  borderRadius: BorderRadius.circular(12),
                  onTap: isLoading
                      ? null
                      : () async {
                          final cancelCubit = context
                              .read<CancelCustomJobRequestCubit>();
                          final requestId = job.id ?? widget.customJobRequestId;

                          int reasonCount = 0;
                          try {
                            final reasons = await BookingRepository()
                                .getCancelReasons();
                            reasonCount = reasons.length;
                          } catch (_) {}

                          if (!context.mounted) return;

                          if (reasonCount == 0) {
                            cancelCubit.cancelBooking(
                              customJobRequestId: requestId,
                              cancelReasonId: '',
                              additionalInfo: null,
                            );
                            return;
                          }

                          UiUtils.showBottomSheet(
                            context: context,
                            enableDrag: true,
                            isScrollControlled: true,
                            useSafeArea: true,
                            child: BlocProvider<FetchCancelReasonsCubit>(
                              create: (_) => FetchCancelReasonsCubit(
                                bookingRepository: BookingRepository(),
                              ),
                              child: BookingCancelReasonBottomSheet(
                                onConfirm:
                                    (reasonId, reasonText, additionalInfo) {
                                      cancelCubit.cancelBooking(
                                        customJobRequestId: requestId,
                                        cancelReasonId: reasonId,
                                        cancelReasonText: reasonText,
                                        additionalInfo: additionalInfo,
                                      );
                                    },
                              ),
                            ),
                          );
                        },
                  child: Center(
                    child: isLoading
                        ? CustomCircularProgressIndicator(
                            color: context.colors.textError,
                            widthAndHeight: 22,
                          )
                        : CustomText(
                            'cancelRequest'.translate(context: context),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: context.colors.textError,
                          ),
                  ),
                ),
              ),
            );
          },
        ),
  );

  Widget _buildShimmer() => const SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        CustomShimmerLoadingContainer(borderRadius: 8, height: 180),
        CustomSizedBox(height: 12),
        CustomShimmerLoadingContainer(borderRadius: 8, height: 220),
        CustomSizedBox(height: 12),
        CustomShimmerLoadingContainer(borderRadius: 8, height: 120),
      ],
    ),
  );

  Widget _buildRequestDetailsTab(
    final BuildContext context,
    final CustomJob job,
  ) => SingleChildScrollView(
    controller: _scrollController,
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      UiUtils.getScrollViewBottomPadding(context) + 25,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryCard(context, job),
        const CustomSizedBox(height: 12),
        _buildRequestDetailsCard(context, job),
        const CustomSizedBox(height: 12),
        _buildAttachmentCard(context, job),
        const CustomSizedBox(height: 12),
      ],
    ),
  );

  Widget _buildBookedRequestBody(
    final BuildContext context,
    final CustomJob job,
    final String currentStatus,
  ) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      UiUtils.getScrollViewBottomPadding(context) + 25,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryCard(context, job),
        if (job.bidDetails != null) ...[
          const CustomSizedBox(height: 16),
          CustomText(
            'selectedProviderBid'.translate(context: context),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: context.colors.textPrimary,
          ),
          const CustomSizedBox(height: 8),
          _buildBidderCard(context, job.bidDetails!, currentStatus),
        ],
        const CustomSizedBox(height: 12),
        _buildRequestDetailsCard(context, job),
        const CustomSizedBox(height: 12),
        _buildAttachmentCard(context, job),
      ],
    ),
  );

  Widget _buildViewBookingButton(final BuildContext context) => CustomContainer(
    width: double.infinity,
    color: context.colors.backgroundPrimary,
    padding: const EdgeInsets.all(16),
    boxShadow: [
      BoxShadow(
        color: context.colors.overlayFooterShadow,
        offset: const Offset(0, -2),
        blurRadius: 8,
      ),
    ],
    child: CustomRoundedButton(
      widthPercentage: 1,
      height: 48,
      radius: UiUtils.borderRadiusOf12,
      backgroundColor: context.colors.backgroundBrand,
      titleColor: context.colors.textInverseLight,
      buttonTitle: 'viewBooking'.translate(context: context),
      showBorder: false,
      textSize: 16,
      fontWeight: FontWeight.w500,
      onTap: () => Navigator.pushNamed(
        context,
        bookingDetails,
        arguments: {
          'bookingId': widget.customJobRequestId,
          // 'customRequestOrder': '1',
        },
      ),
    ),
  );

  Widget _buildRequestNewServiceButton(final BuildContext context) =>
      CustomContainer(
        width: double.infinity,
        color: context.colors.backgroundPrimary,
        padding: const EdgeInsets.all(16),
        boxShadow: [
          BoxShadow(
            color: context.colors.overlayFooterShadow,
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
        child: CustomRoundedButton(
          widthPercentage: 1,
          height: 48,
          radius: UiUtils.borderRadiusOf12,
          backgroundColor: context.colors.backgroundBrand,
          titleColor: context.colors.textInverseLight,
          buttonTitle: 'requestNewService'.translate(context: context),
          showBorder: false,
          textSize: 16,
          fontWeight: FontWeight.w500,
          onTap: () => Navigator.pushNamed(
            context,
            requestServiceCategorySelectionScreen,
          ),
        ),
      );

  @override
  Widget build(final BuildContext context) {
    return BlocConsumer<MyRequestDetailsCubit, MyRequestDetailsState>(
      listener: (ctx, state) {
        if (state is MyRequestDetailsSuccess) {
          _startCountdown(state.requestCustomJob);
        }
      },
      builder: (ctx, state) {
        final String currentStatus = state is MyRequestDetailsSuccess
            ? (state.requestCustomJob.status ?? widget.status)
            : widget.status;

        final int bidCount = state is MyRequestDetailsSuccess
            ? state.bidders.length
            : 0;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: UiUtils.getSystemUiOverlayStyle(context: context),
          child: Scaffold(
            backgroundColor: context.colors.backgroundSecondary,
            appBar: UiUtils.getSimpleAppBar(
              context: context,
              title: 'requestDetails'.translate(context: context),
              isLeadingIconEnable: true,
              bottom: currentStatus == 'booked'
                  ? null
                  : PreferredSize(
                      preferredSize: const Size.fromHeight(44),
                      child: TopRoundedUnderlineTabBar(
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                            color: context.colors.overlayHeaderShadow,
                          ),
                        ],
                        controller: _tabController,
                        height: 44,
                        tabs: [
                          Text('requestDetails'.translate(context: context)),
                          Text(
                            '${'providerBid'.translate(context: context)} ($bidCount)',
                          ),
                        ],
                      ),
                    ),
            ),
            body: () {
              if (state is MyRequestDetailsInProgress) {
                return _buildShimmer();
              }
              if (state is MyRequestDetailsFailure) {
                return ErrorContainer(
                  errorMessage: state.errorMessage.translate(context: context),
                  onTapRetry: fetchServiceDetails,
                  showRetryButton: true,
                );
              }
              if (state is MyRequestDetailsSuccess) {
                final job = state.requestCustomJob;
                if (currentStatus == 'booked') {
                  return _buildBookedRequestBody(context, job, currentStatus);
                }
                return Stack(
                  children: [
                    TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRequestDetailsTab(context, job),
                        _buildProviderBidTab(
                          context,
                          state.bidders,
                          currentStatus,
                          selectedSortBy: state.selectedSortBy,
                          isSorting: state.isSortingBidders,
                        ),
                      ],
                    ),
                    if (_canCancel(currentStatus))
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildCancelButton(context, job),
                      ),
                  ],
                );
              }
              return const SizedBox.shrink();
            }(),
            bottomNavigationBar: currentStatus == 'booked'
                ? _buildViewBookingButton(context)
                : currentStatus == 'expiry'
                ? _buildRequestNewServiceButton(context)
                : null,
          ),
        );
      },
    );
  }
}
