import 'package:e_demand/app/generalImports.dart';
import 'package:e_demand/ui/widgets/scheduledMaintainanceContainer.dart';
import 'package:flutter/material.dart'; // ignore_for_file: use_build_context_synchronously

import 'widgets/sliderImageWidget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.scrollController, final Key? key})
    : super(key: key);

  final ScrollController scrollController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late ValueNotifier<int> currentSearchValueIndex = ValueNotifier(0);
  FocusNode searchBarFocusNode = FocusNode();
  List<String> searchValues = [
    "searchProviders",
    "searchServices",
    "searchElectronics",
    "searchHairCutting",
    "searchFanRepair",
  ];

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  );

  late final Animation<double> _bottomToCenterTextAnimation =
      Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.0, 0.25),
        ),
      );

  late final Animation<double> _centerToTopTextAnimation =
      Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.75, 1.0),
        ),
      );

  late Timer? _timer;

  @override
  void dispose() {
    searchBarFocusNode.dispose();
    currentSearchValueIndex.dispose();
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initialiseAnimation();
    AppQuickActions.initAppQuickActions();
    AppQuickActions.createAppQuickActions();

    checkLocationPermission();

    LocalAwesomeNotification.init(context);
  }

  Future<void> fetchHomeScreenData() async {
    await context.read<SystemSettingCubit>().getSystemSettings();
    final futureAPIs = <Future>[
      context.read<HomeScreenCubit>().fetchHomeScreenData(),
      if (HiveRepository.getUserToken != '') ...[
        context.read<CartCubit>().getCartDetails(isReorderCart: false),
        context.read<BookmarkCubit>().fetchBookmark(type: 'list'),
      ],
    ];

    await Future.wait(futureAPIs);
  }

  Future<void> checkLocationPermission() async {
    final LocationPermission permission = await Geolocator.checkPermission();

    if ((permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) &&
        ((HiveRepository.getLatitude == "0.0" ||
                HiveRepository.getLatitude == '') &&
            (HiveRepository.getLongitude == "0.0" ||
                HiveRepository.getLongitude == ''))) {
      Future.delayed(Duration.zero, () {
        Navigator.pushNamed(context, allowLocationScreenRoute);
      });
    }
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      Position position;

      if (HiveRepository.getLatitude != null &&
          HiveRepository.getLongitude != null &&
          HiveRepository.getLatitude != '' &&
          HiveRepository.getLongitude != '') {
        final latitude = HiveRepository.getLatitude ?? "0.0";
        final longitude = HiveRepository.getLongitude ?? "0.0";

        await GeocodingPlatform.instance!.placemarkFromCoordinates(
          double.parse(latitude.toString()),
          double.parse(longitude.toString()),
        );
      } else {
        position = await Geolocator.getCurrentPosition();
        await GeocodingPlatform.instance!.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
      }

      setState(() {});
    }
  }

  Widget _getSearchBarContainer() {
    return CustomInkWellContainer(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        ClarityService.logAction(ClarityActions.searchScreenOpened, {
          'source': 'home_top_search',
        });
        await Navigator.pushNamed(context, searchCategoriesScreen);
      },
      child: CustomContainer(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: context.colors.backgroundPrimary,
        borderRadius: 12,
        avoideResponsive: true,
        child: Row(
          children: [
            CustomSvgPicture(
              svgImage: AppAssets.search,
              height: 24,
              width: 24,
              color: context.colors.iconPrimary,
              avoideResponsive: true,
            ),
            const CustomSizedBox(width: 8),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: currentSearchValueIndex,
                builder: (context, int searchValueIndex, _) {
                  return AnimatedBuilder(
                    animation: _bottomToCenterTextAnimation,
                    builder: (context, child) {
                      final dy =
                          _bottomToCenterTextAnimation.value -
                          _centerToTopTextAnimation.value;

                      final opacity =
                          1 -
                          _bottomToCenterTextAnimation.value -
                          _centerToTopTextAnimation.value;

                      return CustomContainer(
                        height: 48,
                        alignment: Alignment(-1, dy),
                        child: Opacity(
                          opacity: opacity,
                          child: CustomText(
                            searchValues[searchValueIndex].translate(
                              context: context,
                            ),
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.normal,
                            fontSize: 14,
                            maxLines: 1,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeHeader() {
    return CustomContainer(
      color: context.colors.backgroundBrand,
      padding: EdgeInsetsDirectional.only(
        top: MediaQuery.paddingOf(context).top + 12,
        start: 16,
        end: 16,
        bottom: 16,
      ),
      borderRadiusStyle: const BorderRadius.only(
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: CustomInkWellContainer(
                  onTap: locationOnTap,
                  child: Row(
                    children: [
                      CustomContainer(
                        width: 40,
                        height: 40,
                        borderRadius: 20,
                        color: context.colors.backgroundSecondary,
                        clipBehavior: Clip.antiAlias,
                        child:
                            (HiveRepository.getUserProfilePictureURL == null ||
                                HiveRepository.getUserProfilePictureURL == '')
                            ? Padding(
                                padding: const EdgeInsets.all(8),
                                child: CustomSvgPicture(
                                  svgImage: AppAssets.user,
                                  color: context.colors.iconPrimary,
                                ),
                              )
                            : CustomCachedNetworkImage(
                                height: 40,
                                width: 40,
                                fit: BoxFit.cover,
                                networkImageUrl: HiveRepository
                                    .getUserProfilePictureURL
                                    .toString(),
                              ),
                      ),
                      const CustomSizedBox(width: 8),
                      Expanded(
                        child: ValueListenableBuilder(
                          valueListenable: Hive.box(
                            HiveRepository.userDetailBoxKey,
                          ).listenable(),
                          builder: (BuildContext context, Box box, _) {
                            final String? locationArea =
                                HiveRepository.getLocationArea;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: CustomText(
                                        (HiveRepository.getLocationName ==
                                                    null ||
                                                HiveRepository
                                                    .getLocationName!
                                                    .isEmpty)
                                            ? "selectYourLocation".translate(
                                                context: context,
                                              )
                                            : HiveRepository.getLocationName!,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: context.colors.textInverseLight,
                                        maxLines: 1,
                                      ),
                                    ),
                                    const CustomSizedBox(width: 4),
                                    CustomSvgPicture(
                                      svgImage: AppAssets.downArrow,
                                      height: 20,
                                      width: 20,
                                      avoideResponsive: true,
                                      color: context.colors.iconInverseLight,
                                    ),
                                  ],
                                ),
                                if (locationArea != null &&
                                    locationArea.isNotEmpty)
                                  CustomText(
                                    locationArea,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: context.colors.textInverseLight,
                                    maxLines: 1,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const CustomSizedBox(width: 12),
              CustomInkWellContainer(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  final authStatus = context.read<AuthenticationCubit>().state;
                  if (authStatus is UnAuthenticatedState) {
                    UiUtils.showBottomSheet(
                      context: context,
                      enableDrag: true,
                      isScrollControlled: true,
                      useSafeArea: true,
                      child: const LoginRequiredBottomSheet(),
                    );
                    return;
                  }
                  ClarityService.logAction(ClarityActions.notificationOpened, {
                    'previous_route': Routes.currentRoute,
                  });
                  Navigator.pushNamed(context, notificationRoute);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colors.backgroundPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: CustomSvgPicture(
                    svgImage: AppAssets.notification,
                    height: 24,
                    width: 24,
                    color: context.colors.iconPrimary,
                    avoideResponsive: true,
                  ),
                ),
              ),
            ],
          ),
          const CustomSizedBox(height: 16),
          _getSearchBarContainer(),
        ],
      ),
    );
  }

  Widget _getCategoryTextContainer() => Padding(
    padding: const EdgeInsetsDirectional.only(start: 15, end: 15),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomText(
          'seviceCategory'.translate(context: context),
          color: context.colors.textPrimary,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.normal,
          fontSize: 16,
          textAlign: TextAlign.left,
        ),
        CustomInkWellContainer(
          onTap: () {
            Navigator.pushNamed(context, allCategoriesRoute);
          },
          child: CustomText(
            'viewAll'.translate(context: context),
            color: context.colors.textBrand,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.normal,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );

  Widget _getCategoryListContainer({
    required final List<CategoryModel> categoryList,
  }) => categoryList.isEmpty
      ? const CustomSizedBox()
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _getCategoryTextContainer(),
            const CustomSizedBox(height: 12),
            Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: 15.rw(context),
              ),
              child: CustomContainer(
                color: context.colors.backgroundPrimary,
                borderRadius: UiUtils.borderRadiusOf12,
                padding: EdgeInsets.all(12.rh(context)),
                child: _getCategoryItemsContainer(
                  categoryList
                      .take(ResponsiveHelper.isTabletDevice(context) ? 10 : 8)
                      .toList(),
                ),
              ),
            ),
          ],
        );

  Widget _getTitleShimmerEffect({
    required final double height,
    required final double width,
    required final double borderRadius,
  }) => CustomShimmerLoadingContainer(
    width: width,
    height: height,
    borderRadius: borderRadius,
  );

  Widget _getCategoryShimmerEffect() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 15, end: 15, top: 15),
        child: _getTitleShimmerEffect(
          width: 350,
          height: 20,
          borderRadius: UiUtils.borderRadiusOf10,
        ),
      ),
      Padding(
        padding: EdgeInsetsDirectional.only(top: 15.rs(context)),
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.symmetric(horizontal: 5.rw(context)),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              UiUtils.numberOfShimmerContainer,
              (final int index) => const Column(
                children: [
                  CustomShimmerLoadingContainer(
                    width: 210,
                    height: 60,
                    borderRadius: UiUtils.borderRadiusOf10,
                    margin: EdgeInsets.symmetric(horizontal: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _getSingleSectionShimmerEffect() => Padding(
    padding: EdgeInsetsDirectional.only(top: 15.rs(context)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: 15.rw(context)),
          child: _getTitleShimmerEffect(
            width: 350,
            height: 20,
            borderRadius: UiUtils.borderRadiusOf10,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              ResponsiveHelper.isTabletDevice(context) ? 9 : 4,
              (final int index) => Padding(
                padding: EdgeInsetsDirectional.only(
                  top: 10.rw(context),
                  end: 5.rw(context),
                  start: 5.rw(context),
                ),
                child: const CustomShimmerLoadingContainer(
                  width: 120,
                  height: 140,
                  borderRadius: UiUtils.borderRadiusOf10,
                  margin: EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  void _openServiceDetails(final Services service) {
    Navigator.pushNamed(
      context,
      providerServiceDetails,
      arguments: {
        'serviceDetails': service,
        'serviceId': service.id ?? '',
        'providerId': service.userId ?? '0',
      },
    );
  }

  void locationOnTap() {
    Navigator.pushNamed(context, setLocationRoute).then((final result) {
      final Map? value = result as Map?;
      if (value != null) {
        if (value['navigateToMap']) {
          Navigator.pushNamed(
            context,
            googleMapRoute,
            arguments: {
              "defaultLatitude": value['latitude'].toString(),
              "defaultLongitude": value['longitude'].toString(),
              'showAddressForm': false,
              'screenType': GoogleMapScreenType.selectLocationOnMap,
            },
          );
        }
      }
    });
  }

  Widget _getSections({required final List<Sections> sectionsList}) {
    bool renderedFirstVisible = false;
    return Column(
      children: List.generate(sectionsList.length, (index) {
        final bool isCustomJobRequestSection =
            sectionsList[index].sectionType == 'custom_job_requests';
        final bool isEmptySection =
            !isCustomJobRequestSection &&
            sectionsList[index].providers.isEmpty &&
            sectionsList[index].onGoingBookings.isEmpty &&
            sectionsList[index].previousBookings.isEmpty &&
            sectionsList[index].services.isEmpty &&
            sectionsList[index].offers.isEmpty &&
            sectionsList[index].categories.isEmpty &&
            (sectionsList[index].bannerImage ?? '').isEmpty;
        if (isEmptySection) return const CustomSizedBox();

        final bool isFirstVisible = !renderedFirstVisible;
        renderedFirstVisible = true;
        return _getSingleSectionContainer(
          sectionsList[index],
          isFirstVisible: isFirstVisible,
        );
      }),
    );
  }

  Widget _getSingleSectionContainer(
    final Sections sectionData, {
    final bool isFirstVisible = false,
  }) => SingleChildScrollView(
    child: BlocBuilder<UserDetailsCubit, UserDetailsState>(
      builder: (context, state) {
        final token = HiveRepository.getUserToken;
        if ((sectionData.sectionType == "previous_order" && token == '') ||
            (sectionData.sectionType == "ongoing_order" && token == ''))
          return const CustomSizedBox();

        final double topGap = isFirstVisible ? 0 : 24;

        if (sectionData.sectionType == 'all_categories') {
          return Padding(
            padding: EdgeInsetsDirectional.only(top: topGap),
            child: _getCategoryListContainer(
              categoryList: sectionData.categories,
            ),
          );
        }

        if (sectionData.sectionType == 'categories') {
          return Padding(
            padding: EdgeInsetsDirectional.only(top: topGap),
            child: _getFeaturedCategoriesSection(sectionData),
          );
        }

        if (sectionData.sectionType == 'banner') {
          return Padding(
            padding: EdgeInsetsDirectional.only(top: topGap),
            child: _getBannerSection(sectionData),
          );
        }

        if (sectionData.sectionType == 'custom_job_requests') {
          return Padding(
            padding: EdgeInsetsDirectional.only(
              start: 15,
              end: 15,
              top: topGap,
            ),
            child: RequestServiceBannerWidget(
              title: sectionData.translatedTitle,
              subtitle: sectionData.description,
            ),
          );
        }

        if (sectionData.offers.isNotEmpty) {
          return Padding(
            padding: EdgeInsetsDirectional.only(
              top: topGap,
              start: 15,
              end: 15,
            ),
            child: OffersSectionWidget(
              offers: sectionData.offers,
              layoutType: sectionData.offersLayoutType ?? 'one_image',
            ),
          );
        }

        return CustomContainer(
          margin: EdgeInsetsDirectional.only(top: topGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _getSingleSectionTitle(sectionData),
              CustomSizedBox(height: 8.rh(context)),
              _getSingleSectionData(sectionData),
            ],
          ),
        );
      },
    ),
  );

  Widget _getSingleSectionTitle(
    final Sections sectionData, {
    final bool showViewAll = true,
  }) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 15, end: 15),
    child: Row(
      spacing: 16,
      children: [
        Expanded(
          child: CustomText(
            sectionData.translatedTitle!,
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 16,
            maxLines: 1,
            textAlign: TextAlign.left,
          ),
        ),
        if (showViewAll)
          CustomInkWellContainer(
            onTap: () {
              final bool isBookingSection =
                  sectionData.onGoingBookings.isNotEmpty ||
                  sectionData.previousBookings.isNotEmpty;
              if (isBookingSection) {
                UiUtils
                        .bottomNavigationBarGlobalKey
                        .currentState
                        ?.selectedIndexOfBottomNavigationBar
                        .value =
                    1;
                Navigator.of(context).popUntil((final route) => route.isFirst);
                return;
              }
              Navigator.pushNamed(
                context,
                sectionDetailsRoute,
                arguments: {'sectionData': sectionData},
              );
            },
            child: CustomText(
              'viewAll'.translate(context: context),
              color: context.colors.textBrand,
              fontSize: 14,
            ),
          ),
      ],
    ),
  );

  Widget _getSingleSectionData(final Sections sectionData) {
    return CustomSizedBox(
      width: context.screenWidth,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.only(end: 15, start: 15),
        physics: const AlwaysScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            sectionData.providers.isNotEmpty
                ? sectionData.providers.length
                : sectionData.services.isNotEmpty
                ? sectionData.services.length
                : sectionData.onGoingBookings.isNotEmpty
                ? sectionData.onGoingBookings.length
                : sectionData.previousBookings.isNotEmpty
                ? sectionData.previousBookings.length
                : 0,
            (index) {
              if (sectionData.providers.isNotEmpty) {
                final Providers provider = sectionData.providers[index];
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: SizedBox(
                    width: 305.rw(context),
                    child: ProviderCard(
                      providerDetails: provider,
                      height: 76,
                      width: 80,
                      showBanner: sectionData.providersLayoutType == 'style_1',
                      highlightStat:
                          sectionData.sectionType == 'top_rated_partner'
                          ? 'rating'
                          : 'distance',
                      onTap: () {
                        ClarityService.logAction(
                          ClarityActions.homePopularServiceTapped,
                          {
                            'provider_id': provider.id ?? '',
                            'provider_name':
                                provider.translatedCompanyName ??
                                provider.companyName,
                            'services_count': provider.totalServices ?? '',
                            'section': sectionData.sectionType ?? '',
                          },
                        );
                        Navigator.pushNamed(
                          context,
                          providerRoute,
                          arguments: {"providerId": provider.id},
                        ).then((final Object? value) {
                          //we are changing the route name
                          //to use CartSubDetailsContainer widget to navigate to provider details screen
                          Routes.previousRoute = Routes.currentRoute;
                          Routes.currentRoute = navigationRoute;
                        });
                      },
                    ),
                  ),
                );
              } else if (sectionData.services.isNotEmpty) {
                final Services service = sectionData.services[index];
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: SizedBox(
                    width: 305.rw(context),
                    child: ServiceCard(
                      imageWidth: 55,
                      imageHeight: 72,
                      useDashedDivider: true,
                      showBorder: false,
                      addButtonBackgroundColor:
                          context.colors.backgroundBrandSubtle,
                      serviceId: service.id ?? '',
                      providerId: service.userId ?? '0',
                      title: service.translatedTitle,
                      image: service.imageOfTheService,
                      price: service.price,
                      discountedPrice: service.discountedPrice,
                      discountPercentage: service.discountPercentage,
                      duration: service.duration,
                      durationType: service.durationType,
                      numberOfMembersRequired: service.numberOfMembersRequired,
                      averageRating: service.averageRating ?? service.rating,
                      maximumAllowedQuantity:
                          int.tryParse(service.maxQuantityAllowed ?? '0') ?? 0,
                      isBookmarked: service.isBookmarked,
                      companyName: service.companyName,
                      isProviderVerified: service.isProviderVerified ?? false,
                      onTap: () => _openServiceDetails(service),
                    ),
                  ),
                );
              } else if (sectionData.onGoingBookings.isNotEmpty ||
                  sectionData.previousBookings.isNotEmpty) {
                final bool isOngoing = sectionData.onGoingBookings.isNotEmpty;
                final List<BookingListItem> bookings = isOngoing
                    ? sectionData.onGoingBookings
                    : sectionData.previousBookings;
                final BookingListItem bookingData = bookings[index];
                if (isOngoing) {
                  final bool anyHasMoreServices = bookings.any(
                    (final b) => (b.otherServicesCount ?? 0) > 0,
                  );
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: OngoingBookingCard(
                      booking: bookingData,
                      reserveMoreServicesLine: anyHasMoreServices,
                    ),
                  );
                }
                final bool anyHasMoreServices = bookings.any(
                  (final b) => (b.otherServicesCount ?? 0) > 0,
                );
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: SizedBox(
                    width: 305.rw(context),
                    child: BookingSummaryCard(
                      booking: bookingData,
                      reserveMoreServicesLine: anyHasMoreServices,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          bookingDetails,
                          arguments: {"bookingId": bookingData.id},
                        );
                      },
                    ),
                  ),
                );
              }
              return const CustomSizedBox();
            },
          ),
        ),
      ),
    );
  }

  Widget _categoryItem(final CategoryModel category) => CustomInkWellContainer(
    onTap: () {
      UiUtils.navigateToCategoryDetails(
        context,
        categoryId: category.id,
        categoryName: category.name,
      );
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomContainer(
          width: 48,
          height: 48,
          borderRadius: 24,
          color: context.colors.backgroundSecondary,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(12),
          child: CustomCachedNetworkImage(
            networkImageUrl: category.categoryImage ?? '',
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            defaultColourFilter: false,
          ),
        ),
        const CustomSizedBox(height: 6),
        CustomText(
          category.name ?? '',
          fontSize: 12,
          color: context.colors.textPrimary,
          textAlign: TextAlign.center,
          maxLines: 1,
        ),
      ],
    ),
  );

  Widget _getCategoryItemsContainer(final List<CategoryModel> categoryList) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final int crossAxisCount = ResponsiveHelper.isTabletDevice(context)
              ? 5
              : 4;
          const double spacing = 24;
          final double itemWidth =
              (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
              crossAxisCount;
          return Wrap(
            spacing: spacing,
            runSpacing: 16,
            children: List.generate(categoryList.length, (index) {
              return SizedBox(
                width: itemWidth,
                child: _categoryItem(categoryList[index]),
              );
            }),
          );
        },
      );

  /// Range for showing a "categories" section as the fixed grid (same as
  /// all_categories) versus a horizontally-scrollable row: too few items
  /// leaves the grid's full-width background card looking mostly empty,
  /// and too many can't fit the grid without truncating some silently.
  int get _categoryGridMinItems => 4;
  int get _categoryGridMaxItems =>
      ResponsiveHelper.isTabletDevice(context) ? 10 : 8;

  Widget _getFeaturedCategoriesSection(final Sections sectionData) {
    final List<CategoryModel> categories = sectionData.categories;
    final bool useGrid =
        categories.length >= _categoryGridMinItems &&
        categories.length <= _categoryGridMaxItems;
    final Widget content = useGrid
        ? Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: 15.rw(context),
            ),
            child: CustomContainer(
              color: context.colors.backgroundPrimary,
              borderRadius: UiUtils.borderRadiusOf12,
              padding: EdgeInsets.all(12.rh(context)),
              child: _getCategoryItemsContainer(categories),
            ),
          )
        : Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: 15.rw(context),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: categories
                    .map(
                      (final category) => Padding(
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        child: CustomContainer(
                          width: 88,
                          color: context.colors.backgroundPrimary,
                          borderRadius: UiUtils.borderRadiusOf12,
                          padding: EdgeInsets.all(12.rh(context)),
                          child: _categoryItem(category),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _getSingleSectionTitle(sectionData, showViewAll: false),
        CustomSizedBox(height: 12.rh(context)),
        content,
      ],
    );
  }

  Widget _getBannerSection(final Sections sectionData) {
    if ((sectionData.bannerImage ?? '').isEmpty) return const CustomSizedBox();
    // CustomCachedNetworkImage collapses to zero height without an explicit
    // height (its underlying Container has no child, just a decoration
    // image) — matching the top slider's own height convention.
    final double bannerHeight = ResponsiveHelper.isTabletDevice(context)
        ? 260
        : 200.rs(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 15, end: 15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(UiUtils.borderRadiusOf12),
        child: CustomCachedNetworkImage(
          networkImageUrl: sectionData.bannerImage!,
          width: double.infinity,
          height: bannerHeight,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _homeScreenShimmerLoading() => SingleChildScrollView(
    padding: EdgeInsetsDirectional.only(
      bottom: UiUtils.getScrollViewBottomPadding(context),
    ),
    child: Column(
      children: [
        _getSliderImageShimmerEffect(),
        const CustomSizedBox(height: 15),
        _getCategoryShimmerEffect(),
        Column(
          children: List.generate(
            UiUtils.numberOfShimmerContainer,
            (final int index) => _getSingleSectionShimmerEffect(),
          ),
        ),
      ],
    ),
  );

  Widget _getSliderImageShimmerEffect() => Padding(
    padding: EdgeInsetsDirectional.only(
      start: 15.rw(context),
      end: 15.rw(context),
      top: 15.rh(context),
    ),
    child: CustomShimmerLoadingContainer(
      width: context.screenWidth,
      height: 200.rh(context),
      borderRadius: UiUtils.borderRadiusOf10,
    ),
  );

  void _initialiseAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (currentSearchValueIndex.value != searchValues.length - 1) {
        currentSearchValueIndex.value += 1;
      } else {
        currentSearchValueIndex.value = 0;
      }
      _animationController.forward(from: 0.0);
    });

    _animationController.forward();
  }

  @override
  Widget build(
    final BuildContext context,
  ) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: UiUtils.getSystemUiOverlayStyle(context: context).copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
    child: SafeArea(
      top: false,
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                _buildHomeHeader(),
                Expanded(
                  child: BlocBuilder<SystemSettingCubit, SystemSettingState>(
                    builder: (context, SystemSettingState systemSettingState) {
                      // Show loading shimmer if system settings are not loaded yet
                      if (systemSettingState is! SystemSettingFetchSuccess) {
                        if (systemSettingState is SystemSettingFetchFailure) {
                          return ErrorContainer(
                            errorMessage: systemSettingState.errorMessage
                                .toString()
                                .translate(context: context),
                            onTapRetry: () {
                              fetchHomeScreenData();
                            },
                          );
                        }

                        return _homeScreenShimmerLoading();
                      }

                      return BlocBuilder<CartCubit, CartState>(
                        // we have added Cart cubit
                        // because we want to calculate bottom padding of scroll
                        builder:
                            (
                              final BuildContext context,
                              final CartState state,
                            ) => BlocBuilder<HomeScreenCubit, HomeScreenState>(
                              builder: (context, HomeScreenState homeScreenState) {
                                if (homeScreenState
                                    is HomeScreenDataFetchSuccess) {
                                  final cartButtonHeight =
                                      context
                                              .read<CartCubit>()
                                              .getProviderIDFromCartData() ==
                                          '0'
                                      ? 0
                                      : kBottomNavigationBarHeight.rh(context) +
                                            30.rf(context);
                                  if (homeScreenState
                                          .homeScreenData
                                          .sections!
                                          .isEmpty &&
                                      homeScreenState
                                          .homeScreenData
                                          .sliders!
                                          .isEmpty) {
                                    return Center(
                                      child: NoDataFoundWidget(
                                        titleKey: 'weAreNotAvailableHere'
                                            .translate(context: context),
                                        subtitleKey:
                                            'weAreNotAvailableHereSubTitle'
                                                .translate(context: context),
                                        buttonName: "changeLocation".translate(
                                          context: context,
                                        ),
                                        onTapRetry: locationOnTap,
                                        showRetryButton: true,
                                      ),
                                    );
                                  }
                                  return CustomRefreshIndicator(
                                    onRefreshCallback: fetchHomeScreenData,
                                    displacment: 12,
                                    child: SingleChildScrollView(
                                      controller: widget.scrollController,
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: EdgeInsetsDirectional.only(
                                        bottom:
                                            UiUtils.getScrollViewBottomPadding(
                                              context,
                                            ) +
                                            24.rh(context) +
                                            cartButtonHeight,
                                      ),
                                      child: Column(
                                        children: [
                                          const CustomSizedBox(height: 25),
                                          if (systemSettingState
                                                  .systemSettingDetails
                                                  .appSetting !=
                                              null) ...[
                                            ScheduledMaintenanceContainer(
                                              appSettings: systemSettingState
                                                  .systemSettingDetails
                                                  .appSetting!,
                                            ),
                                          ],
                                          if (homeScreenState
                                              .homeScreenData
                                              .sliders!
                                              .isNotEmpty) ...[
                                            SliderImageWidget(
                                              sliderImages: homeScreenState
                                                  .homeScreenData
                                                  .sliders!,
                                            ),
                                            const CustomSizedBox(height: 24),
                                          ],
                                          _getSections(
                                            sectionsList: homeScreenState
                                                .homeScreenData
                                                .sections!,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else if (homeScreenState
                                    is HomeScreenDataFetchFailure) {
                                  return ErrorContainer(
                                    errorMessage: homeScreenState.errorMessage
                                        .translate(context: context),
                                    onTapRetry: () {
                                      fetchHomeScreenData();
                                    },
                                  );
                                }
                                return _homeScreenShimmerLoading();
                              },
                            ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsetsDirectional.only(
                bottom: kBottomNavigationBarHeight + 18,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: CartSubDetailsContainer(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
