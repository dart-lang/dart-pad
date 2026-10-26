// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/split_panel.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

import '../../../split_panel_fixture.dart';

final class _SplitOwner extends ValueNotifier<SplitState> {
  _SplitOwner({required SplitState initialState}) : super(initialState);

  bool get isObserved => hasListeners;
}

void main() {
  group('SplitPanel', () {
    testClient('switches listeners when its owner changes', (tester) async {
      final first = _SplitOwner(initialState: const Split(0.6));
      final second = _SplitOwner(initialState: const RightHidden(0.4));
      final currentOwner = ValueNotifier<ValueListenable<SplitState>>(first);
      addTearDown(() async {
        tester.binding.detachRootComponent();
        await pumpEventQueue();
        first.dispose();
        second.dispose();
        currentOwner.dispose();
      });
      final key = GlobalStateKey<SplitPanelState>();
      Component layout(ValueListenable<SplitState> owner) => SplitPanel(
        key: key,
        state: owner,
        left: const div(id: 'left-pane', []),
        right: const div(id: 'right-pane', []),
      );

      tester.pumpComponent(ValueListenableBuilder(listenable: currentOwner, builder: (_, owner) => layout(owner)));
      final mountedState = key.currentState;
      expect(first.isObserved, isTrue);
      expect(second.isObserved, isFalse);

      currentOwner.value = second;
      await pumpEventQueue();
      expect(key.currentState, same(mountedState));
      expect(first.isObserved, isFalse);
      expect(second.isObserved, isTrue);
      expect((web.document.querySelector('#right-pane')! as web.HTMLElement).style.display, 'none');

      second.value = const Split(0.4);
      await pumpEventQueue();
      expect((web.document.querySelector('#right-pane')! as web.HTMLElement).style.display, isEmpty);
      expect(key.currentState!.state, const Split(0.4));
    });

    testClient('removes its listener when unmounted without disposing the owner', (tester) async {
      final owner = _SplitOwner(initialState: const Split(0.5));
      addTearDown(() async {
        tester.binding.detachRootComponent();
        await pumpEventQueue();
        owner.dispose();
      });
      tester.pumpComponent(SplitPanel(state: owner, left: const div([]), right: const div([])));
      expect(owner.isObserved, isTrue);

      tester.binding.detachRootComponent();
      await pumpEventQueue();
      expect(owner.isObserved, isFalse);
      owner.value = const RightCollapsed(0.5);
      expect(owner.value, const RightCollapsed(0.5));
    });

    testClient('controlled split reports requests and waits for its owner', (tester) async {
      final key = GlobalStateKey<SplitPanelState>();
      final requests = <SplitState>[];
      final owner = createSplitOwner(tester, const Split(0.6));
      tester.pumpComponent(
        SplitPanel(
          key: key,
          state: owner,
          onStateChanged: requests.add,
          left: const div(id: 'left-pane', []),
          right: const div(id: 'right-pane', []),
        ),
      );
      key.currentState!.collapseRight();
      await pumpEventQueue();
      expect(requests, const [RightCollapsed(0.6)]);
      expect(key.currentState!.state, const Split(0.6));

      owner.value = requests.single;
      await pumpEventQueue();
      expect(key.currentState!.state, const RightCollapsed(0.6));
      expect(requests, hasLength(1));
      key.currentState!.split();
      await pumpEventQueue();
      expect(requests, const [RightCollapsed(0.6), Split(0.6)]);
      owner.value = requests.last;
      await pumpEventQueue();
      expect(key.currentState!.state, const Split(0.6));
    });

    testClient('controlled drag updates the owner and survives remounting', (tester) async {
      final state = ValueNotifier<SplitState>(const Split(0.5));
      addTearDown(() async {
        tester.binding.detachRootComponent();
        await pumpEventQueue();
        state.dispose();
      });
      final key = GlobalStateKey<SplitPanelState>();
      Component layout() => div(
        styles: Styles(display: .flex, width: 500.px),
        [
          SplitPanel(
            key: key,
            state: state,
            onStateChanged: (value) => state.value = value,
            left: const div([]),
            right: const div([]),
          ),
        ],
      );
      final showPanel = ValueNotifier(true);
      tester.pumpComponent(
        div([
          ListenableBuilder(listenable: showPanel, builder: (_) => showPanel.value ? layout() : const div([])),
        ]),
      );
      final handle = web.document.querySelector('.drag-handle')! as web.HTMLElement;
      final rect = handle.parentElement!.getBoundingClientRect();
      handle.dispatchEvent(web.MouseEvent('mousedown', web.MouseEventInit(clientX: (rect.left + 250).round())));
      web.window.dispatchEvent(web.MouseEvent('mousemove', web.MouseEventInit(clientX: (rect.left + 300).round())));
      await pumpEventQueue();
      web.window.dispatchEvent(web.MouseEvent('mouseup'));
      await pumpEventQueue();
      expect(state.value, const Split(0.6));
      showPanel.value = false;
      await pumpEventQueue();
      showPanel.value = true;
      await pumpEventQueue();
      expect(key.currentState!.state, const Split(0.6));
    });

    testClient('renders left, right and drag handle', (tester) {
      tester.pumpComponent(
        SplitPanel(
          state: createSplitOwner(tester, const Split(0.5)),
          left: const div(id: 'left-pane', [Component.text('left')]),
          right: const div(id: 'right-pane', [Component.text('right')]),
        ),
      );

      expect(web.document.querySelector('#left-pane'), isNotNull);
      expect(web.document.querySelector('#right-pane'), isNotNull);
      expect(web.document.querySelector('.drag-handle'), isNotNull);
    });

    testClient('renders vertical drag handle when isVertical is true', (tester) {
      tester.pumpComponent(
        SplitPanel(
          state: createSplitOwner(tester, const Split(0.5)),
          isVertical: true,
          left: const div(id: 'top-pane', [Component.text('top')]),
          right: const div(id: 'bottom-pane', [Component.text('bottom')]),
        ),
      );

      expect(web.document.querySelector('.drag-handle.vertical'), isNotNull);
    });

    testClient('renders collapsed second panel sizing to intrinsic size (no fixed basis)', (tester) {
      tester.pumpComponent(
        SplitPanel(
          state: createSplitOwner(tester, const RightCollapsed(0.5)),
          isVertical: true,
          left: const div(id: 'top-pane', [Component.text('top')]),
          right: const div(id: 'bottom-pane', [Component.text('bottom')]),
        ),
      );

      final bottomPane = web.document.querySelector('#bottom-pane')! as web.HTMLElement;
      expect(bottomPane.style.flexBasis, isEmpty);
      expect(bottomPane.style.flexShrink, '0');
    });

    testClient('auto-expands when dragging collapsed handle up', (tester) async {
      final splitKey = GlobalStateKey<SplitPanelState>();
      tester.pumpComponent(
        div(
          styles: Styles(
            display: .flex,
            height: 500.px,
            flexDirection: .column,
          ),
          [
            withSplitOwner(
              tester,
              const RightCollapsed(0.75),
              (state, onChanged) => SplitPanel(
                state: state,
                onStateChanged: onChanged,
                key: splitKey,
                canCollapseRight: true,
                isVertical: true,
                useRatio: true,
                maxValue: 0.8,
                left: const div(id: 'top-pane', [Component.text('top')]),
                right: const div(id: 'bottom-pane', [Component.text('bottom')]),
              ),
            ),
          ],
        ),
      );

      final handle = web.document.querySelector('.drag-handle')! as web.HTMLElement;
      expect(handle, isNotNull);

      // Start drag at Y=460 (collapsed handle near bottom)
      handle.dispatchEvent(web.MouseEvent('mousedown', web.MouseEventInit(clientY: 460, clientX: 100)));
      await pumpEventQueue();

      // Drag up by 30px to Y=430 (delta = 30 > 10)
      web.window.dispatchEvent(web.MouseEvent('mousemove', web.MouseEventInit(clientY: 430, clientX: 100)));
      await pumpEventQueue();

      expect(splitKey.currentState!.isRightCollapsed, isFalse);

      // Finish drag
      web.window.dispatchEvent(web.MouseEvent('mouseup', web.MouseEventInit(clientY: 430, clientX: 100)));
      await pumpEventQueue();
    });

    testClient('dragging collapsed handle does not flicker when expanding in small increments', (tester) async {
      final splitKey = GlobalStateKey<SplitPanelState>();
      tester.pumpComponent(
        div(
          styles: Styles(
            display: .flex,
            height: 500.px,
            flexDirection: .column,
          ),
          [
            withSplitOwner(
              tester,
              const RightCollapsed(0.75),
              (state, onChanged) => SplitPanel(
                state: state,
                onStateChanged: onChanged,
                key: splitKey,
                canCollapseRight: true,
                isVertical: true,
                useRatio: true,
                maxValue: 0.8,
                left: const div(id: 'top-pane', [Component.text('top')]),
                right: const div(id: 'bottom-pane', [Component.text('bottom')]),
              ),
            ),
          ],
        ),
      );

      final handle = web.document.querySelector('.drag-handle')! as web.HTMLElement;
      expect(handle, isNotNull);

      // Start drag at Y=460 (collapsed handle near bottom)
      handle.dispatchEvent(web.MouseEvent('mousedown', web.MouseEventInit(clientY: 460, clientX: 100)));
      await pumpEventQueue();

      // Drag up past initial expand delta (Y=445, delta = 15 > 10)
      web.window.dispatchEvent(web.MouseEvent('mousemove', web.MouseEventInit(clientY: 445, clientX: 100)));
      await pumpEventQueue();
      expect(splitKey.currentState!.isRightCollapsed, isFalse);

      // Move in small 1px increments (currentSecondPos is still below collapseThreshold):
      // Must NOT flicker back to collapsed!
      web.window.dispatchEvent(web.MouseEvent('mousemove', web.MouseEventInit(clientY: 444, clientX: 100)));
      await pumpEventQueue();
      expect(splitKey.currentState!.isRightCollapsed, isFalse);

      web.window.dispatchEvent(web.MouseEvent('mousemove', web.MouseEventInit(clientY: 440, clientX: 100)));
      await pumpEventQueue();
      expect(splitKey.currentState!.isRightCollapsed, isFalse);

      // Finish drag
      web.window.dispatchEvent(web.MouseEvent('mouseup', web.MouseEventInit(clientY: 440, clientX: 100)));
      await pumpEventQueue();
    });

    testClient('auto-collapses when dragging expanded handle down too small', (tester) async {
      final splitKey = GlobalStateKey<SplitPanelState>();
      tester.pumpComponent(
        div(
          styles: Styles(
            display: .flex,
            height: 500.px,
            flexDirection: .column,
          ),
          [
            withSplitOwner(
              tester,
              const Split(0.75),
              (state, onChanged) => SplitPanel(
                state: state,
                onStateChanged: onChanged,
                key: splitKey,
                canCollapseRight: true,
                isVertical: true,
                maxValue: 0.8,
                left: const div(id: 'top-pane', [Component.text('top')]),
                right: const div(id: 'bottom-pane', [Component.text('bottom')]),
              ),
            ),
          ],
        ),
      );

      final handle = web.document.querySelector('.drag-handle')! as web.HTMLElement;
      expect(handle, isNotNull);

      // Start drag at Y=375 (expanded position)
      handle.dispatchEvent(web.MouseEvent('mousedown', web.MouseEventInit(clientY: 375, clientX: 100)));
      await pumpEventQueue();

      // Drag down towards bottom: Y=470 (currentSecondPos = 500 - 470 = 30, which is < collapseThreshold 70)
      web.window.dispatchEvent(web.MouseEvent('mousemove', web.MouseEventInit(clientY: 470, clientX: 100)));
      await pumpEventQueue();

      expect(splitKey.currentState!.isRightCollapsed, isTrue);

      // Finish drag
      web.window.dispatchEvent(web.MouseEvent('mouseup', web.MouseEventInit(clientY: 470, clientX: 100)));
      await pumpEventQueue();
    });

    testClient('auto-collapses left when dragging handle too small with both canCollapseLeft and canCollapseRight', (
      tester,
    ) async {
      final splitKey = GlobalStateKey<SplitPanelState>();
      tester.pumpComponent(
        div(
          styles: Styles(
            display: .flex,
            height: 500.px,
            flexDirection: .column,
          ),
          [
            withSplitOwner(
              tester,
              const Split(0.5),
              (state, onChanged) => SplitPanel(
                state: state,
                onStateChanged: onChanged,
                key: splitKey,
                canCollapseLeft: true,
                canCollapseRight: true,
                isVertical: true,
                left: const div(id: 'top-pane', [Component.text('top')]),
                right: const div(id: 'bottom-pane', [Component.text('bottom')]),
              ),
            ),
          ],
        ),
      );

      final handle = web.document.querySelector('.drag-handle')! as web.HTMLElement;
      expect(handle, isNotNull);

      // Start drag at Y=250 (expanded position)
      handle.dispatchEvent(web.MouseEvent('mousedown', web.MouseEventInit(clientY: 250, clientX: 100)));
      await pumpEventQueue();

      // Drag up towards top: Y=30 (currentFirstPos = 30 < collapseThresholdLeft 45)
      web.window.dispatchEvent(web.MouseEvent('mousemove', web.MouseEventInit(clientY: 30, clientX: 100)));
      await pumpEventQueue();

      expect(splitKey.currentState!.isLeftCollapsed, isTrue);

      // Finish drag
      web.window.dispatchEvent(web.MouseEvent('mouseup', web.MouseEventInit(clientY: 30, clientX: 100)));
      await pumpEventQueue();
    });

    testClient('auto-expands left-collapsed handle when both canCollapseLeft and canCollapseRight are enabled', (
      tester,
    ) async {
      final splitKey = GlobalStateKey<SplitPanelState>();
      tester.pumpComponent(
        div(
          styles: Styles(
            display: .flex,
            height: 500.px,
            flexDirection: .column,
          ),
          [
            withSplitOwner(
              tester,
              const LeftCollapsed(0.25),
              (state, onChanged) => SplitPanel(
                state: state,
                onStateChanged: onChanged,
                key: splitKey,
                canCollapseLeft: true,
                canCollapseRight: true,
                isVertical: true,
                left: const div(id: 'top-pane', [Component.text('top')]),
                right: const div(id: 'bottom-pane', [Component.text('bottom')]),
              ),
            ),
          ],
        ),
      );

      final handle = web.document.querySelector('.drag-handle')! as web.HTMLElement;
      expect(handle, isNotNull);

      // Start drag at Y=40 (collapsed handle near top)
      handle.dispatchEvent(web.MouseEvent('mousedown', web.MouseEventInit(clientY: 40, clientX: 100)));
      await pumpEventQueue();

      // Drag down by 30px to Y=70 (delta = 30 > 10)
      web.window.dispatchEvent(web.MouseEvent('mousemove', web.MouseEventInit(clientY: 70, clientX: 100)));
      await pumpEventQueue();

      expect(splitKey.currentState!.isLeftCollapsed, isFalse);
      expect(splitKey.currentState!.isRightCollapsed, isFalse);

      // Finish drag
      web.window.dispatchEvent(web.MouseEvent('mouseup', web.MouseEventInit(clientY: 70, clientX: 100)));
      await pumpEventQueue();
    });

    testClient('SplitPanelState requests transitions through its owner', (tester) async {
      final splitKey = GlobalStateKey<SplitPanelState>();
      tester.pumpComponent(
        withSplitOwner(
          tester,
          const Split(0.75),
          (state, onChanged) => SplitPanel(
            state: state,
            onStateChanged: onChanged,
            key: splitKey,
            left: const div([]),
            right: const div([]),
          ),
        ),
      );

      final state = splitKey.currentState!;
      expect(state.state, const Split(0.75));
      expect(state.isSplit, isTrue);
      expect(state.isUncollapsed, isTrue);
      expect(state.isCollapsed, isFalse);
      expect(state.isLeftCollapsed, isFalse);
      expect(state.isRightCollapsed, isFalse);

      state.collapseLeft();
      await pumpEventQueue();
      expect(state.state, const LeftCollapsed(0.75));
      expect(state.isLeftCollapsed, isTrue);
      expect(state.isCollapsed, isTrue);

      state.collapseRight();
      await pumpEventQueue();
      expect(state.state, const RightCollapsed(0.75));
      expect(state.isRightCollapsed, isTrue);
      expect(state.isCollapsed, isTrue);

      state.hideLeft();
      await pumpEventQueue();
      expect(state.state, const LeftHidden(0.75));
      expect(state.isLeftHidden, isTrue);
      expect(state.isHidden, isTrue);

      state.hideRight();
      await pumpEventQueue();
      expect(state.state, const RightHidden(0.75));
      expect(state.isRightHidden, isTrue);
      expect(state.isHidden, isTrue);

      state.split();
      await pumpEventQueue();
      expect(state.state, const Split(0.75));
      expect(state.isSplit, isTrue);
      expect(state.isCollapsed, isFalse);
      expect(state.value, 0.75);
    });

    testClient('SplitPanelState toggles and updates sizes by code', (tester) async {
      final splitKey = GlobalStateKey<SplitPanelState>();
      tester.pumpComponent(
        withSplitOwner(
          tester,
          const Split(0.75),
          (state, onChanged) => SplitPanel(
            state: state,
            onStateChanged: onChanged,
            key: splitKey,
            left: const div([]),
            right: const div([]),
          ),
        ),
      );

      final state = splitKey.currentState!;
      expect(state.value, 0.75);
      expect(state.isCollapsed, isFalse);

      state.collapseRight();
      await pumpEventQueue();
      expect(state.state, const RightCollapsed(0.75));
      expect(state.isCollapsed, isTrue);

      state.split();
      await pumpEventQueue();
      expect(state.state, const Split(0.75));
      expect(state.isCollapsed, isFalse);
      expect(state.value, 0.75);

      state.split(0.6);
      await pumpEventQueue();
      expect(state.value, 0.6);
    });

    testClient('SplitPanelState leftCollapsed and rightCollapsed layout in SplitPanel', (tester) async {
      final splitKey = GlobalStateKey<SplitPanelState>();
      tester.pumpComponent(
        div(
          styles: Styles(
            display: .flex,
            height: 500.px,
            flexDirection: .column,
          ),
          [
            withSplitOwner(
              tester,
              const Split(0.5),
              (state, onChanged) => SplitPanel(
                state: state,
                onStateChanged: onChanged,
                key: splitKey,
                isVertical: true,
                useRatio: true,
                left: const div(id: 'top-pane', [Component.text('top')]),
                right: const div(id: 'bottom-pane', [Component.text('bottom')]),
              ),
            ),
          ],
        ),
      );

      final topPane = web.document.querySelector('#top-pane')! as web.HTMLElement;
      final bottomPane = web.document.querySelector('#bottom-pane')! as web.HTMLElement;

      // Uncollapsed: both have ratio flex basis 0
      expect(topPane.style.flexGrow, '0.5');
      expect(bottomPane.style.flexGrow, '0.5');

      // Collapse left: top pane shrinks to 0, bottom pane grows to 1
      splitKey.currentState!.collapseLeft();
      await pumpEventQueue();

      expect(topPane.style.flexShrink, '0');
      expect(bottomPane.style.flexGrow, '1');

      // Collapse right: top pane grows to 1, bottom pane shrinks to 0
      splitKey.currentState!.collapseRight();
      await pumpEventQueue();

      expect(topPane.style.flexGrow, '1');
      expect(bottomPane.style.flexShrink, '0');

      // Hide right: right pane display none, drag handle removed
      splitKey.currentState!.hideRight();
      await pumpEventQueue();

      expect(web.document.querySelector('.drag-handle'), isNull);
      expect(bottomPane.style.display, 'none');

      // Expand: restored to ratio
      splitKey.currentState!.split();
      await pumpEventQueue();

      expect(web.document.querySelector('.drag-handle'), isNotNull);
      expect(topPane.style.flexGrow, '0.5');
      expect(bottomPane.style.flexGrow, '0.5');
    });

    testClient('SplitPanelState expands and restores value when attached to SplitPanel', (tester) async {
      final splitKey = GlobalStateKey<SplitPanelState>();
      tester.pumpComponent(
        div(
          styles: Styles(
            display: .flex,
            height: 500.px,
            flexDirection: .column,
          ),
          [
            withSplitOwner(
              tester,
              const RightCollapsed(0.75),
              (state, onChanged) => SplitPanel(
                state: state,
                onStateChanged: onChanged,
                key: splitKey,
                isVertical: true,
                useRatio: true,
                minValue: 0.1,
                maxValue: 0.9,
                left: const div(id: 'top-pane', [Component.text('top')]),
                right: const div(id: 'bottom-pane', [Component.text('bottom')]),
              ),
            ),
          ],
        ),
      );

      final state = splitKey.currentState!;
      expect(state.isCollapsed, isTrue);

      state.split();
      await pumpEventQueue();

      expect(state.isCollapsed, isFalse);
      expect(state.value, 0.75);

      // Can expand to explicit targetValue
      state.collapseRight();
      await pumpEventQueue();
      expect(state.isCollapsed, isTrue);

      state.split(0.6);
      await pumpEventQueue();
      expect(state.isCollapsed, isFalse);
      expect(state.value, 0.6);
    });

    testClient('SplitPanel.of(context) exposes SplitPanelData to descendants', (tester) async {
      SplitPanelData? leftData;
      SplitPanelData? rightData;
      SplitPanelData? noListenRightData;

      tester.pumpComponent(
        withSplitOwner(
          tester,
          const Split(0.5),
          (state, onChanged) => SplitPanel(
            state: state,
            onStateChanged: onChanged,
            canCollapseLeft: true,
            canCollapseRight: true,
            left: _ContextInspector(onBuild: (ctx) => leftData = SplitPanel.of(ctx)),
            right: _ContextInspector(
              onBuild: (ctx) {
                rightData = SplitPanel.of(ctx);
                noListenRightData = SplitPanel.of(ctx, listen: false);
              },
            ),
          ),
        ),
      );

      expect(leftData, isNotNull);
      expect(leftData!.canCollapse, isTrue);
      expect(leftData!.isPanelCollapsed, isFalse);

      expect(rightData, isNotNull);
      expect(rightData!.canCollapse, isTrue);
      expect(rightData!.isPanelCollapsed, isFalse);
      expect(noListenRightData, isNotNull);

      // Collapse right panel via SplitPanelData
      rightData!.collapse();
      await pumpEventQueue();

      expect(rightData!.isPanelCollapsed, isTrue);
      expect(leftData!.isPanelCollapsed, isFalse);

      // Expand right panel
      rightData!.expand();
      await pumpEventQueue();

      expect(rightData!.isPanelCollapsed, isFalse);

      // Collapse left panel via SplitPanelData
      leftData!.collapse();
      await pumpEventQueue();

      expect(leftData!.isPanelCollapsed, isTrue);
    });
  });
}

class _ContextInspector extends StatelessComponent {
  const _ContextInspector({this.onBuild});

  final void Function(BuildContext context)? onBuild;

  @override
  Component build(BuildContext context) {
    onBuild?.call(context);
    return const div([]);
  }
}
