# Implementation Plan: relief-map-phases

## Overview

This plan implements Phase 1 of the ReliefLink map zone interaction feature. The implementation adds an interactive bottom sheet that appears when users tap heatmap zones, displaying aggregate summaries and a scrollable list of requests. The work is broken into four main areas: modifying the ReliefMap widget to support tap callbacks, creating the new ZoneSummarySheet widget with all its sub-components, wiring the sheet into MapScreen, and adding property-based tests to validate correctness properties.

## Tasks

- [ ] 1. Add zone tap callback to ReliefMap widget
  - Modify `lib/widgets/relief_map.dart` to add `onZoneTap` parameter
  - Add `final ValueChanged<RequestCluster>? onZoneTap;` to ReliefMap constructor
  - Update `_onZoneTap` method in `_ReliefMapState` to call `widget.onZoneTap?.call(cluster)` instead of zooming in
  - Add guard: only call callback if `cluster.count > 0`
  - Update hint text to "Tap a zone to see requests in that area."
  - _Requirements: 1.1, 1.3, 1.4, 1.5_

- [ ] 2. Create ZoneSummarySheet widget and sub-components
  - [ ] 2.1 Create base ZoneSummarySheet structure
    - Create `lib/widgets/zone_summary_sheet.dart`
    - Implement `ZoneSummarySheet` StatelessWidget with parameters: `cluster`, `isOffline`, `onSelectRequest`
    - Set up `DraggableScrollableSheet` with initialChildSize: 0.55, minChildSize: 0.3, maxChildSize: 0.92
    - Add drag handle UI element at top
    - _Requirements: 3.4, 5.1, 5.2, 5.3, 5.4_
  
  - [ ]* 2.2 Write property test for breakdown count sums
    - **Property 2: Type and priority breakdown counts sum to total**
    - **Validates: Requirements 2.1, 2.2, 2.3**
  
  - [ ] 2.3 Implement ZoneSheetHeader component
    - Create `_ZoneSheetHeader` widget showing priority color strip, "Zone Summary" label, and total count badge
    - Use `cluster.color` for left-side color bar
    - Display `cluster.count` in badge
    - _Requirements: 2.1_
  
  - [ ] 2.4 Implement TypeBreakdownRow component
    - Create `_TypeBreakdownRow` widget with four `_CountChip` widgets in a Row
    - Compute type counts: `{ for (final t in RequestType.values) t: 0 }` then iterate cluster.requests
    - Display all four types (medical, food, rescue, shelter) even if count is 0
    - Use `requestTypeIcon` and `requestTypeLabel` from models
    - _Requirements: 2.2, 2.4_
  
  - [ ]* 2.5 Write property test for all types present
    - **Property 3: All four types always present in breakdown**
    - **Validates: Requirements 2.4**
  
  - [ ] 2.6 Implement PriorityBreakdownRow component
    - Create `_PriorityBreakdownRow` widget with four `_CountChip` widgets in a Row
    - Compute priority counts: `{ for (final p in RequestPriority.values) p: 0 }` then iterate cluster.requests
    - Display all four priorities (critical, high, medium, low) even if count is 0
    - Use `requestPriorityLabel` and `priorityColor` from models
    - _Requirements: 2.3, 2.5_
  
  - [ ]* 2.7 Write property test for all priorities present
    - **Property 4: All four priorities always present in breakdown**
    - **Validates: Requirements 2.5**
  
  - [ ] 2.8 Implement offline banner component
    - Create `_OfflineBanner` widget with warning icon and "Data may not be current" message
    - Show conditionally based on `isOffline` parameter
    - _Requirements: 6.2_
  
  - [ ]* 2.9 Write property test for offline banner visibility
    - **Property 9: Offline banner shown if and only if offline**
    - **Validates: Requirements 6.2**
  
  - [ ] 2.10 Implement RequestListItem component
    - Create `_RequestListItem` widget displaying: type icon (colored by priority), priority label, type label, description (2-line truncation with overflow ellipsis), people count badge
    - Make tappable with `InkWell` or `GestureDetector`
    - Call `onSelectRequest(request)` on tap
    - Use `requestTypeIcon`, `requestTypeLabel`, `requestPriorityLabel`, `priorityColor` from models
    - _Requirements: 3.2, 4.1_
  
  - [ ] 2.11 Assemble complete ZoneSummarySheet layout
    - Build Column with fixed header section: drag handle, ZoneSheetHeader, offline banner (conditional), TypeBreakdownRow, PriorityBreakdownRow, Divider
    - Add Expanded ListView below header with priority-sorted RequestListItem widgets
    - Sort requests: `[...cluster.requests]..sort((a, b) => priorityRank(a.priority).compareTo(priorityRank(b.priority)))`
    - Ensure header stays fixed while list scrolls independently
    - _Requirements: 3.1, 3.3, 3.5, 6.1, 6.3_
  
  - [ ]* 2.12 Write property test for priority sort order
    - **Property 5: Request list is priority-sorted**
    - **Validates: Requirements 3.3**
  
  - [ ]* 2.13 Write property test for sheet list matches cluster
    - **Property 6: Sheet list is exactly the cluster's requests**
    - **Validates: Requirements 3.1, 6.1, 6.3**

- [ ] 3. Wire ZoneSummarySheet into MapScreen
  - Modify `lib/screens/map_screen.dart` to import `ZoneSummarySheet` and `RequestCluster`
  - Add `_showZoneSheet(RequestCluster cluster)` method using `showModalBottomSheet`
  - Set `isScrollControlled: true` and `backgroundColor: Colors.transparent`
  - Pass `cluster`, `isOffline: !SyncService.instance.online`, and `onSelectRequest: _openRequestDetail` to ZoneSummarySheet
  - Add `_openRequestDetail(ReliefRequest request)` method to navigate to `RequestDetailScreen`
  - Pass `onZoneTap: _showZoneSheet` to ReliefMap widget
  - _Requirements: 1.3, 4.1, 4.2, 5.1, 5.2, 6.2_

- [ ] 4. Checkpoint - Ensure all tests pass
  - Run all property-based tests and unit tests
  - Verify zone tap opens sheet with correct data
  - Verify offline banner appears when offline
  - Verify request list is priority-sorted
  - Verify tapping request navigates to detail screen
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests use the `fast_check` package with minimum 100 iterations
- The checkpoint ensures incremental validation before completion
- All aggregate counts are computed inline in ZoneSummarySheet.build
- The existing RequestDetailScreen already handles missing requests gracefully
