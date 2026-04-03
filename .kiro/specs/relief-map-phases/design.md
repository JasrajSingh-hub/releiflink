# Design Document

## Feature: relief-map-phases (Phase 1 — Zone Tap Bottom Sheet)

## Overview

Phase 1 adds interactive zone-tap behaviour to the existing heatmap view. When a user taps a coloured heatmap zone bubble at zoom < 13, a modal bottom sheet slides up showing an aggregate summary of all requests in that cluster, followed by a scrollable priority-sorted list of individual requests. Tapping any request in the list navigates to the existing `RequestDetailScreen`. The sheet is dismissible by swipe or tap-outside, and the map remains pannable/zoomable behind it.

The change is additive: the existing zoom-in behaviour on zone tap is replaced by the bottom sheet (zooming in is now done by the user manually, or by tapping a request pin after dismissal).

## Architecture

The feature touches three layers:

```
ReliefMap (widget)
  └─ _onZoneTap(cluster)  →  calls new onZoneTap callback
        ↓
MapScreen (screen)
  └─ _showZoneSheet(cluster)  →  showModalBottomSheet
        ↓
ZoneSummarySheet (new widget)
  ├─ ZoneSheetHeader
  ├─ TypeBreakdownRow
  ├─ PriorityBreakdownRow
  └─ RequestListItem (scrollable, taps → RequestDetailScreen)
```

`ReliefMap` stays a pure display widget — it fires a callback and does nothing else on zone tap. All sheet logic lives in `MapScreen` and the new `ZoneSummarySheet` widget.

### Data flow

`MapScreen` already holds the filtered `List<ReliefRequest>` that is passed to `ReliefMap`. When a zone tap fires, `MapScreen` receives the `RequestCluster` (which already contains the filtered subset of requests for that cluster, because `buildClusters` is called on the filtered list). No additional filtering is needed inside the sheet.

Offline mode is detected via `SyncService.instance.online`. When offline, the sheet shows a banner indicating data may not be current.

## Components and Interfaces

### 1. `ReliefMap` — new `onZoneTap` callback

```dart
// Add to ReliefMap constructor
final ValueChanged<RequestCluster>? onZoneTap;
```

`_onZoneTap` in `_ReliefMapState` changes from zooming in to calling the callback:

```dart
void _onZoneTap(RequestCluster cluster) {
  widget.onZoneTap?.call(cluster);
  // zoom-in removed; user can zoom manually
}
```

The hint text when in heatmap mode updates to: `"Tap a zone to see requests in that area."`.

### 2. `MapScreen` — `_showZoneSheet`

```dart
void _showZoneSheet(RequestCluster cluster) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ZoneSummarySheet(
      cluster: cluster,
      isOffline: !SyncService.instance.online,
      onSelectRequest: _openRequestDetail,
    ),
  );
}
```

`ReliefMap` in `MapScreen.build` gains `onZoneTap: _showZoneSheet`.

### 3. `ZoneSummarySheet` (new — `lib/widgets/zone_summary_sheet.dart`)

```dart
class ZoneSummarySheet extends StatelessWidget {
  const ZoneSummarySheet({
    super.key,
    required this.cluster,
    required this.isOffline,
    required this.onSelectRequest,
  });

  final RequestCluster cluster;
  final bool isOffline;
  final ValueChanged<ReliefRequest> onSelectRequest;
}
```

Internal layout (fixed header + scrollable list):

```
DraggableScrollableSheet
  └─ Column
       ├─ drag handle
       ├─ ZoneSheetHeader      (priority color strip + total count)
       ├─ [offline banner]     (conditional)
       ├─ TypeBreakdownRow     (medical / food / rescue / shelter counts)
       ├─ PriorityBreakdownRow (critical / high / medium / low counts)
       ├─ Divider
       └─ Expanded → ListView  (priority-sorted RequestListItem widgets)
```

`DraggableScrollableSheet` with `initialChildSize: 0.55`, `minChildSize: 0.3`, `maxChildSize: 0.92` gives the swipe-to-dismiss feel and lets the list scroll independently.

### 4. `ZoneSheetHeader`

Displays a left-side colour bar (dominant priority colour), the zone label ("Zone Summary"), and the total request count badge.

### 5. `TypeBreakdownRow`

Four `_CountChip` widgets in a `Row` — one per `RequestType`. Always shows all four, even if count is 0.

### 6. `PriorityBreakdownRow`

Four `_CountChip` widgets in a `Row` — one per `RequestPriority`. Always shows all four, even if count is 0.

### 7. `RequestListItem`

Tappable card showing: type icon (coloured by priority), priority label, type label, description (2-line truncation), people count badge. Tapping calls `onSelectRequest(request)` which navigates to `RequestDetailScreen` via `MapScreen._openRequestDetail`.

## Data Models

No new models are needed. The existing `RequestCluster` already carries everything required:

| Field | Used for |
|---|---|
| `cluster.requests` | source list for the sheet |
| `cluster.dominantPriority` | header colour |
| `cluster.count` | total count badge |
| `cluster.color` | header colour strip |

Aggregate counts are computed inline in `ZoneSummarySheet.build`:

```dart
// Type counts
final typeCounts = { for (final t in RequestType.values) t: 0 };
for (final r in cluster.requests) typeCounts[r.type] = typeCounts[r.type]! + 1;

// Priority counts
final priorityCounts = { for (final p in RequestPriority.values) p: 0 };
for (final r in cluster.requests) priorityCounts[r.priority] = priorityCounts[r.priority]! + 1;

// Sorted list
final sorted = [...cluster.requests]
  ..sort((a, b) => priorityRank(a.priority).compareTo(priorityRank(b.priority)));
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Zone tap guard — non-empty clusters only

*For any* `RequestCluster`, `_onZoneTap` must invoke `onZoneTap` if and only if `cluster.count > 0`. An empty cluster must never trigger the bottom sheet.

**Validates: Requirements 1.3, 1.4**

---

### Property 2: Type and priority breakdown counts sum to total

*For any* `RequestCluster`, both the sum of all per-type counts and the sum of all per-priority counts computed for the sheet must each equal `cluster.count`.

**Validates: Requirements 2.1, 2.2, 2.3**

---

### Property 3: All four types always present in breakdown

*For any* `RequestCluster`, the type breakdown always contains exactly one entry for each of the four `RequestType` values (`medical`, `food`, `rescue`, `shelter`), even when a type's count is zero.

**Validates: Requirements 2.4**

---

### Property 4: All four priorities always present in breakdown

*For any* `RequestCluster`, the priority breakdown always contains exactly one entry for each of the four `RequestPriority` values (`critical`, `high`, `medium`, `low`), even when a priority's count is zero.

**Validates: Requirements 2.5**

---

### Property 5: Request list is priority-sorted

*For any* `RequestCluster`, the sorted request list produced for the sheet must be non-decreasing in `priorityRank` — i.e., no request appears before a request with a strictly higher priority.

**Validates: Requirements 3.3**

---

### Property 6: Sheet list is exactly the cluster's requests

*For any* `RequestCluster`, the set of request IDs shown in the sheet's scrollable list must be exactly equal (no additions, no omissions) to the IDs in `cluster.requests`. This also guarantees filter consistency, since the cluster is built from the already-filtered list.

**Validates: Requirements 3.1, 6.1, 6.3**

---

### Property 7: Each list item renders required fields

*For any* `ReliefRequest` rendered as a `RequestListItem`, the rendered widget must contain a representation of the request's type, priority, description, and `peopleCount`.

**Validates: Requirements 3.2**

---

### Property 8: Tapping a list item calls onSelectRequest with the correct request

*For any* `RequestCluster` and any request `r` in `cluster.requests`, tapping the corresponding `RequestListItem` must invoke `onSelectRequest` with exactly `r` (matched by `r.id`).

**Validates: Requirements 4.1**

---

### Property 9: Offline banner shown if and only if offline

*For any* `ZoneSummarySheet` instantiation, the offline data banner is visible if and only if `isOffline` is `true`.

**Validates: Requirements 6.2**

---

## Error Handling

| Scenario | Handling |
|---|---|
| Cluster with 0 requests reaches `_onZoneTap` | Guard in `_onZoneTap`: only call `onZoneTap` if `cluster.count > 0` |
| `tryParseLatLng` returns null for a request | Already handled upstream in `buildClusters` — unparseable requests are excluded |
| `RequestDetailScreen` not found (request deleted between tap and navigation) | `RequestDetailScreen` already handles `request == null` with a "not found" scaffold |
| Sheet opened while offline | Offline banner shown; data is from Hive cache which is always available |

## Testing Strategy

### Unit tests (`test/widgets/zone_summary_sheet_test.dart`)

- Render sheet with a cluster of mixed types/priorities → verify all four type chips and all four priority chips are present
- Render sheet with a single-type cluster → verify that type has count > 0, others show 0
- Render sheet with `isOffline: true` → verify offline banner is visible
- Render sheet with `isOffline: false` → verify offline banner is absent
- Tap a `RequestListItem` → verify `onSelectRequest` is called with the correct request

### Property-based tests (`test/widgets/zone_summary_sheet_property_test.dart`)

Uses the [`fast_check`](https://pub.dev/packages/fast_check) package (Dart PBT library). Each test runs a minimum of 100 iterations.

**Property 2 — Breakdown counts sum to total**
```
// Feature: relief-map-phases, Property 2: type and priority counts sum to cluster.count
forAll(arbitraryCluster, (cluster) {
  final typeCounts = computeTypeCounts(cluster.requests);
  final priorityCounts = computePriorityCounts(cluster.requests);
  expect(typeCounts.values.sum, equals(cluster.count));
  expect(priorityCounts.values.sum, equals(cluster.count));
});
```

**Property 3 & 4 — All enum values always present**
```
// Feature: relief-map-phases, Property 3 & 4: all types and priorities present
forAll(arbitraryCluster, (cluster) {
  final typeCounts = computeTypeCounts(cluster.requests);
  final priorityCounts = computePriorityCounts(cluster.requests);
  expect(typeCounts.keys.toSet(), equals(RequestType.values.toSet()));
  expect(priorityCounts.keys.toSet(), equals(RequestPriority.values.toSet()));
});
```

**Property 5 — Priority sort order**
```
// Feature: relief-map-phases, Property 5: request list is priority-sorted
forAll(arbitraryCluster, (cluster) {
  final sorted = sortByPriority(cluster.requests);
  for (var i = 0; i < sorted.length - 1; i++) {
    expect(
      priorityRank(sorted[i].priority),
      lessThanOrEqualTo(priorityRank(sorted[i + 1].priority)),
    );
  }
});
```

**Property 6 — Sheet list matches cluster requests**
```
// Feature: relief-map-phases, Property 6: sheet list IDs match cluster request IDs
forAll(arbitraryCluster, (cluster) {
  final sorted = sortByPriority(cluster.requests);
  expect(
    sorted.map((r) => r.id).toSet(),
    equals(cluster.requests.map((r) => r.id).toSet()),
  );
});
```

**Property 9 — Offline banner visibility**
```
// Feature: relief-map-phases, Property 9: offline banner shown iff isOffline
forAll(arbitraryCluster.flatMap((c) => arbitraryBool.map((b) => (c, b))), (pair) {
  final (cluster, isOffline) = pair;
  // render ZoneSummarySheet and check banner finder
  expect(offlineBannerFinder.evaluate().isNotEmpty, equals(isOffline));
});
```

Both unit and property tests are complementary: unit tests cover concrete rendering snapshots and interaction callbacks; property tests verify the aggregate computation logic holds across all possible cluster shapes.
