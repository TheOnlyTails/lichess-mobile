import 'package:auto_size_text/auto_size_text.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lichess_mobile/src/model/broadcast/broadcast.dart';
import 'package:lichess_mobile/src/model/broadcast/broadcast_providers.dart';
import 'package:lichess_mobile/src/model/broadcast/broadcast_round_controller.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/view/broadcast/broadcast_boards_tab.dart';
import 'package:lichess_mobile/src/view/broadcast/broadcast_overview_tab.dart';
import 'package:lichess_mobile/src/widgets/adaptive_bottom_sheet.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/list.dart';

class BroadcastRoundScreen extends ConsumerStatefulWidget {
  final Broadcast broadcast;

  const BroadcastRoundScreen({required this.broadcast});

  @override
  _BroadcastRoundScreenState createState() => _BroadcastRoundScreenState();
}

enum _ViewMode { overview, boards }

class _BroadcastRoundScreenState extends ConsumerState<BroadcastRoundScreen>
    with SingleTickerProviderStateMixin {
  _ViewMode _selectedSegment = _ViewMode.boards;
  late final TabController _tabController;
  late BroadcastTournamentId _selectedTournamentId;
  BroadcastRoundId? _selectedRoundId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(initialIndex: 1, length: 2, vsync: this);
    _selectedTournamentId = widget.broadcast.tour.id;
    _selectedRoundId = widget.broadcast.roundToLinkId;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void setViewMode(_ViewMode mode) {
    setState(() {
      _selectedSegment = mode;
    });
  }

  void setTournamentId(BroadcastTournamentId tournamentId) {
    setState(() {
      _selectedTournamentId = tournamentId;
      _selectedRoundId = null;
    });
  }

  void setRoundId(BroadcastRoundId roundId) {
    setState(() {
      _selectedRoundId = roundId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tournament =
        ref.watch(broadcastTournamentProvider(_selectedTournamentId));

    switch (tournament) {
      case AsyncData(:final value):
        // Eagerly initalize the round controller so it stays alive when switching tabs
        ref.watch(
          broadcastRoundControllerProvider(
            _selectedRoundId ?? value.defaultRoundId,
          ),
        );
        if (Theme.of(context).platform == TargetPlatform.iOS) {
          return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: AutoSizeText(
                widget.broadcast.title,
                minFontSize: 14.0,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              automaticBackgroundVisibility: false,
              border: null,
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Container(
                    height: kMinInteractiveDimensionCupertino,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Styles.cupertinoAppBarColor.resolveFrom(context),
                      border: const Border(
                        bottom: BorderSide(
                          color: Color(0x4D000000),
                          width: 0.0,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        bottom: 8.0,
                      ),
                      child: CupertinoSlidingSegmentedControl<_ViewMode>(
                        groupValue: _selectedSegment,
                        children: {
                          _ViewMode.overview:
                              Text(context.l10n.broadcastOverview),
                          _ViewMode.boards: Text(context.l10n.broadcastBoards),
                        },
                        onValueChanged: (_ViewMode? view) {
                          if (view != null) {
                            setState(() {
                              _selectedSegment = view;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: _selectedSegment == _ViewMode.overview
                        ? BroadcastOverviewTab(
                            broadcast: widget.broadcast,
                            tournamentId: _selectedTournamentId,
                          )
                        : BroadcastBoardsTab(
                            _selectedRoundId ?? value.defaultRoundId,
                          ),
                  ),
                  _BottomBar(
                    tournament: value,
                    roundId: _selectedRoundId ?? value.defaultRoundId,
                    setTournamentId: setTournamentId,
                    setRoundId: setRoundId,
                  ),
                ],
              ),
            ),
          );
        } else {
          return Scaffold(
            appBar: AppBar(
              title: AutoSizeText(
                widget.broadcast.title,
                minFontSize: 14.0,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              bottom: TabBar(
                controller: _tabController,
                tabs: <Widget>[
                  Tab(text: context.l10n.broadcastOverview),
                  Tab(text: context.l10n.broadcastBoards),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: <Widget>[
                BroadcastOverviewTab(
                  broadcast: widget.broadcast,
                  tournamentId: _selectedTournamentId,
                ),
                BroadcastBoardsTab(_selectedRoundId ?? value.defaultRoundId),
              ],
            ),
            bottomNavigationBar: _BottomBar(
              tournament: value,
              roundId: _selectedRoundId ?? value.defaultRoundId,
              setTournamentId: setTournamentId,
              setRoundId: setRoundId,
            ),
          );
        }
      case AsyncError(:final error):
        return Center(child: Text(error.toString()));
      case _:
        return const Center(child: CircularProgressIndicator.adaptive());
    }
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({
    required this.tournament,
    required this.roundId,
    required this.setTournamentId,
    required this.setRoundId,
  });

  final BroadcastTournament tournament;
  final BroadcastRoundId roundId;
  final void Function(BroadcastTournamentId) setTournamentId;
  final void Function(BroadcastRoundId) setRoundId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BottomBar(
      children: [
        if (tournament.group != null)
          AdaptiveTextButton(
            onPressed: () => showAdaptiveBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              isDismissible: true,
              builder: (_) => DraggableScrollableSheet(
                initialChildSize: 0.4,
                maxChildSize: 0.4,
                minChildSize: 0.1,
                snap: true,
                expand: false,
                builder: (context, scrollController) {
                  return _TournamentSelectorMenu(
                    tournament: tournament,
                    group: tournament.group!,
                    scrollController: scrollController,
                    setTournamentId: setTournamentId,
                  );
                },
              ),
            ),
            child: Text(
              tournament.group!
                  .firstWhere((g) => g.id == tournament.data.id)
                  .name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        AdaptiveTextButton(
          onPressed: () => showAdaptiveBottomSheet<void>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            isDismissible: true,
            builder: (_) => DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.6,
              snap: true,
              expand: false,
              builder: (context, scrollController) {
                return _RoundSelectorMenu(
                  selectedRoundId: roundId,
                  rounds: tournament.rounds,
                  scrollController: scrollController,
                  setRoundId: setRoundId,
                );
              },
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  tournament.rounds
                      .firstWhere((round) => round.id == roundId)
                      .name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 5.0),
              switch (tournament.rounds
                  .firstWhere((round) => round.id == roundId)
                  .status) {
                RoundStatus.finished =>
                  Icon(Icons.check, color: context.lichessColors.good),
                RoundStatus.live =>
                  Icon(Icons.circle, color: context.lichessColors.error),
                RoundStatus.upcoming =>
                  const Icon(Icons.calendar_month, color: Colors.grey),
              },
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundSelectorMenu extends ConsumerStatefulWidget {
  const _RoundSelectorMenu({
    required this.selectedRoundId,
    required this.rounds,
    required this.scrollController,
    required this.setRoundId,
  });

  final BroadcastRoundId selectedRoundId;
  final IList<BroadcastRound> rounds;
  final ScrollController scrollController;
  final void Function(BroadcastRoundId) setRoundId;

  @override
  ConsumerState<_RoundSelectorMenu> createState() => _RoundSelectorState();
}

final _dateFormat = DateFormat.yMd().add_jm();

class _RoundSelectorState extends ConsumerState<_RoundSelectorMenu> {
  final currentRoundKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Scroll to the current round
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentRoundKey.currentContext != null) {
        Scrollable.ensureVisible(
          currentRoundKey.currentContext!,
          alignment: 0.5,
        );
      }
    });

    return BottomSheetScrollableContainer(
      scrollController: widget.scrollController,
      children: [
        for (final round in widget.rounds)
          PlatformListTile(
            key: round.id == widget.selectedRoundId ? currentRoundKey : null,
            selected: round.id == widget.selectedRoundId,
            title: Text(round.name),
            trailing: switch (round.status) {
              RoundStatus.finished => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_dateFormat.format(round.startsAt!)),
                    const SizedBox(width: 5.0),
                    Icon(Icons.check, color: context.lichessColors.good),
                  ],
                ),
              RoundStatus.live => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_dateFormat.format(round.startsAt!)),
                    const SizedBox(width: 5.0),
                    Icon(Icons.circle, color: context.lichessColors.error),
                  ],
                ),
              RoundStatus.upcoming => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_dateFormat.format(round.startsAt!)),
                    const SizedBox(width: 5.0),
                    const Icon(Icons.calendar_month, color: Colors.grey),
                  ],
                ),
            },
            onTap: () {
              widget.setRoundId(round.id);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

class _TournamentSelectorMenu extends ConsumerStatefulWidget {
  const _TournamentSelectorMenu({
    required this.tournament,
    required this.group,
    required this.scrollController,
    required this.setTournamentId,
  });

  final BroadcastTournament tournament;
  final IList<BroadcastTournamentGroup> group;
  final ScrollController scrollController;
  final void Function(BroadcastTournamentId) setTournamentId;

  @override
  ConsumerState<_TournamentSelectorMenu> createState() =>
      _TournamentSelectorState();
}

class _TournamentSelectorState extends ConsumerState<_TournamentSelectorMenu> {
  final currentTournamentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Scroll to the current tournament
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentTournamentKey.currentContext != null) {
        Scrollable.ensureVisible(
          currentTournamentKey.currentContext!,
          alignment: 0.5,
        );
      }
    });

    return BottomSheetScrollableContainer(
      scrollController: widget.scrollController,
      children: [
        for (final tournament in widget.group)
          PlatformListTile(
            key: tournament.id == widget.tournament.data.id
                ? currentTournamentKey
                : null,
            selected: tournament.id == widget.tournament.data.id,
            title: Text(tournament.name),
            onTap: () {
              widget.setTournamentId(tournament.id);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}
