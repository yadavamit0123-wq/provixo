import 'package:e_demand/app/generalImports.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // ignore_for_file: file_names

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({final Key? key}) : super(key: key);

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();

  static Route route(final RouteSettings routeSettings) => CupertinoPageRoute(
    builder: (final BuildContext context) => const BookmarkScreen(),
  );
}

class _BookmarkScreenState extends State<BookmarkScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );
  final ScrollController _servicesScrollController = ScrollController();
  final ScrollController _providersScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchForTab(_tabController.index);
    _tabController.addListener(_handleTabChange);
    _servicesScrollController.addListener(_fetchMoreServices);
    _providersScrollController.addListener(_fetchMoreProviders);
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      _fetchForTab(_tabController.index);
    }
  }

  void _fetchForTab(final int index) {
    if (index == 0) {
      context.read<ServiceBookmarkCubit>().fetchServiceBookmark();
    } else {
      context.read<BookmarkCubit>().fetchBookmark(type: 'list');
    }
  }

  void _fetchMoreServices() {
    final ServiceBookmarkCubit cubit = context.read<ServiceBookmarkCubit>();
    if (!cubit.hasMoreBookMark()) return;

    final double nextPageTrigger =
        0.7 * _servicesScrollController.position.maxScrollExtent;
    if (_servicesScrollController.position.pixels > nextPageTrigger) {
      if (mounted) cubit.fetchMoreServiceBookmark();
    }
  }

  void _fetchMoreProviders() {
    final BookmarkCubit cubit = context.read<BookmarkCubit>();
    if (!cubit.hasMoreBookMark()) return;

    final double nextPageTrigger =
        0.7 * _providersScrollController.position.maxScrollExtent;
    if (_providersScrollController.position.pixels > nextPageTrigger) {
      if (mounted) cubit.fetchMoreBookmark(type: 'list');
    }
  }

  @override
  void dispose() {
    _servicesScrollController.dispose();
    _providersScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String? _serviceProviderName(final Services service) =>
      (service.translatedPartnerName ?? '').isNotEmpty
      ? service.translatedPartnerName
      : ((service.companyName ?? '').isNotEmpty
            ? service.companyName
            : service.partnerName);

  @override
  Widget build(final BuildContext context) => InterstitialAdWidget(
    child: Scaffold(
      appBar: UiUtils.getSimpleAppBar(
        context: context,
        title: 'bookmark'.translate(context: context),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.rh(context)),
          child: TopRoundedUnderlineTabBar(
            controller: _tabController,
            boxShadow: [
              BoxShadow(
                color: context.colors.overlayHeaderShadow,
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
            tabs: [
              BlocBuilder<ServiceBookmarkCubit, ServiceBookmarkState>(
                builder: (final context, final state) => Text(
                  '${'services'.translate(context: context)} '
                  '(${state is ServiceBookmarkFetchSuccess ? state.totalBookmark : 0})',
                ),
              ),
              BlocBuilder<BookmarkCubit, BookmarkState>(
                builder: (final context, final state) => Text(
                  '${'providers'.translate(context: context)} '
                  '(${state is BookmarkFetchSuccess ? state.totalBookmark : 0})',
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: const BannerAdWidget(),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildServicesTab(), _buildProvidersTab()],
      ),
    ),
  );

  Widget _buildServicesTab() =>
      BlocConsumer<ServiceBookmarkCubit, ServiceBookmarkState>(
        listener:
            (final BuildContext context, final ServiceBookmarkState state) {
              if (state is ServiceBookmarkFetchFailure) {
                UiUtils.showMessage(
                  context,
                  state.errorMessage,
                  ToastificationType.error,
                );
              }
            },
        builder:
            (final BuildContext context, final ServiceBookmarkState state) {
              if (state is ServiceBookmarkFetchFailure) {
                return Center(
                  child: ErrorContainer(
                    errorMessage: state.errorMessage.translate(
                      context: context,
                    ),
                    onTapRetry: () => context
                        .read<ServiceBookmarkCubit>()
                        .fetchServiceBookmark(),
                    showRetryButton: true,
                  ),
                );
              } else if (state is ServiceBookmarkFetchSuccess) {
                if (state.bookmarkList.isEmpty) {
                  return Center(
                    child: NoDataFoundWidget(
                      titleKey: 'noBookmarkFound'.translate(context: context),
                      subtitleKey: 'noBookmarkFoundSubTitle'.translate(
                        context: context,
                      ),
                      imagePath: AppAssets.noBooking,
                    ),
                  );
                }
                return _buildServicesList(
                  services: state.bookmarkList,
                  isLoadingMoreData: state.isLoadingMoreData,
                  isLoadingMoreError: state.isLoadingMoreError,
                );
              }
              return _buildShimmerList();
            },
      );

  Widget _buildServicesList({
    required final List<Services> services,
    required final bool isLoadingMoreData,
    required final bool isLoadingMoreError,
  }) => ListView.separated(
    controller: _servicesScrollController,
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      UiUtils.getScrollViewBottomPadding(context),
    ),
    physics: const AlwaysScrollableScrollPhysics(),
    separatorBuilder: (final _, final __) => const CustomSizedBox(height: 12),
    itemCount:
        services.length + (isLoadingMoreData || isLoadingMoreError ? 1 : 0),
    itemBuilder: (final BuildContext context, final int index) {
      if (index >= services.length) {
        return CustomLoadingMoreContainer(
          isError: isLoadingMoreError,
          onErrorButtonPressed: _fetchMoreServices,
        );
      }
      final Services service = services[index];
      return BlocBuilder<CartCubit, CartState>(
        builder: (final BuildContext context, final _) => ServiceCard(
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
          companyName: service.companyName,
          isProviderVerified: service.isProviderVerified ?? false,
          isBookmarked: service.isBookmarked,
          serviceProviderName: _serviceProviderName(service),
          showBorder: false,
          onBookmarkChanged: (final bool bookmarked) {
            if (!bookmarked) {
              context.read<ServiceBookmarkCubit>().removeBookmark(
                service.id ?? '',
              );
            }
          },
          onTap: () {
            Navigator.pushNamed(
              context,
              providerServiceDetails,
              arguments: {
                'serviceDetails': service,
                'serviceId': service.id ?? '',
                'providerId': service.userId ?? '0',
              },
            );
          },
        ),
      );
    },
  );

  Widget _buildProvidersTab() => BlocConsumer<BookmarkCubit, BookmarkState>(
    listener: (final BuildContext context, final BookmarkState state) {
      if (state is BookmarkFetchFailure) {
        UiUtils.showMessage(
          context,
          state.errorMessage,
          ToastificationType.error,
        );
      }
    },
    builder: (final BuildContext context, final BookmarkState state) {
      if (state is BookmarkFetchFailure) {
        return Center(
          child: ErrorContainer(
            errorMessage: state.errorMessage.translate(context: context),
            onTapRetry: () =>
                context.read<BookmarkCubit>().fetchBookmark(type: 'list'),
            showRetryButton: true,
          ),
        );
      } else if (state is BookmarkFetchSuccess) {
        if (state.bookmarkList.isEmpty) {
          return Center(
            child: NoDataFoundWidget(
              titleKey: 'noBookmarkFound'.translate(context: context),
              subtitleKey: 'noBookmarkFoundSubTitle'.translate(
                context: context,
              ),
              imagePath: AppAssets.noBooking,
            ),
          );
        }
        return _buildProvidersList(
          providers: state.bookmarkList,
          isLoadingMoreData: state.isLoadingMoreData,
          isLoadingMoreError: state.isLoadingMoreError,
        );
      }
      return _buildShimmerList();
    },
  );

  Widget _buildProvidersList({
    required final List<Providers> providers,
    required final bool isLoadingMoreData,
    required final bool isLoadingMoreError,
  }) => ListView.separated(
    controller: _providersScrollController,
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      UiUtils.getScrollViewBottomPadding(context),
    ),
    physics: const AlwaysScrollableScrollPhysics(),
    separatorBuilder: (final _, final __) => const CustomSizedBox(height: 12),
    itemCount:
        providers.length + (isLoadingMoreData || isLoadingMoreError ? 1 : 0),
    itemBuilder: (final BuildContext context, final int index) {
      if (index >= providers.length) {
        return CustomLoadingMoreContainer(
          isError: isLoadingMoreError,
          onErrorButtonPressed: _fetchMoreProviders,
        );
      }
      return ProviderCard(providerDetails: providers[index]);
    },
  );

  Widget _buildShimmerList() => ListView.separated(
    padding: const EdgeInsets.all(16),
    physics: const NeverScrollableScrollPhysics(),
    itemCount: UiUtils.numberOfShimmerContainer,
    separatorBuilder: (final _, final __) => const CustomSizedBox(height: 12),
    itemBuilder: (final BuildContext context, final int index) =>
        const CustomShimmerLoadingContainer(
          height: 176,
          width: double.infinity,
          borderRadius: UiUtils.borderRadiusOf12,
        ),
  );
}
