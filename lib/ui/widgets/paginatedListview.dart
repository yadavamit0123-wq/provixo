import 'package:e_demand/ui/widgets/customLoadingMore.dart';
import 'package:e_demand/ui/widgets/noDataFoundWidget.dart';
import 'package:e_demand/utils/scrollExtension.dart';
import 'package:flutter/material.dart';

class PaginatedListView<T> extends StatefulWidget {
  const PaginatedListView({
    required this.items,
    required this.itemBuilder,
    required this.isLoadingMoreError,
    required this.onLoadMore,
    required this.isLoadingMore,
    required this.separatorBuilder,
    this.header,
    this.noDataTitleKey,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.scrollDirection,
    super.key,
  });

  final List<T> items;
  final Future<void> Function()? onLoadMore;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget Function(BuildContext, T)? separatorBuilder;
  final bool? isLoadingMore;
  final bool isLoadingMoreError;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final String? noDataTitleKey;
  final Axis? scrollDirection;
  final Widget? header;

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addLoadMoreListener(() {
      if (!(widget.isLoadingMore ?? true)) {
        widget.onLoadMore?.call();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      final Widget empty = NoDataFoundWidget(
        titleKey: widget.noDataTitleKey ?? 'noDataFound',
      );
      if (widget.header == null) return empty;
      return ListView(
        physics: widget.physics,
        shrinkWrap: widget.shrinkWrap,
        padding: widget.padding,
        controller: _scrollController,
        children: [widget.header!, empty],
      );
    }

    final int headerOffset = widget.header != null ? 1 : 0;

    return ListView.separated(
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      padding: widget.padding,
      scrollDirection: widget.scrollDirection ?? Axis.vertical,
      controller: _scrollController,
      itemCount:
          headerOffset +
          ((widget.isLoadingMore ?? false)
              ? widget.items.length + 1
              : widget.items.length),
      itemBuilder: (context, index) {
        if (widget.header != null && index == 0) {
          return widget.header!;
        }
        final int itemIndex = index - headerOffset;
        if (itemIndex < widget.items.length) {
          return widget.itemBuilder(context, widget.items[itemIndex]);
        } else {
          return CustomLoadingMore(
            isError: widget.isLoadingMoreError,
            onErrorButtonPressed: () {
              if (!(widget.isLoadingMore ?? true)) {
                widget.onLoadMore?.call();
              }
            },
          );
        }
      },
      separatorBuilder: (context, index) {
        if (widget.header != null && index == 0) {
          return const SizedBox.shrink();
        }
        final int itemIndex = index - headerOffset;
        if (widget.separatorBuilder != null &&
            itemIndex < widget.items.length) {
          return widget.separatorBuilder!(context, widget.items[itemIndex]);
        }
        return const SizedBox.shrink();
      },
    );
  }
}
