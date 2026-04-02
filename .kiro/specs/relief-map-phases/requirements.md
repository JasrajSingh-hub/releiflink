# Requirements Document

## Introduction

This document covers Phase 1 of the remaining ReliefLink map features: zone tap interaction. When a user taps a colored heatmap zone on the map, a bottom sheet slides up presenting a summary of all relief requests within that zone — including counts by type and priority — along with a scrollable list of individual requests. Tapping a request navigates to the existing request detail screen.

## Glossary

- **Map**: The flutter_map-based interactive map screen in the ReliefLink Flutter app
- **Heatmap_Zone**: A colored gradient blob rendered on the Map representing a geographic cluster of ReliefRequests, colored by dominant priority
- **Bottom_Sheet**: A modal panel that slides up from the bottom of the screen, overlaying the Map
- **Zone_Summary**: The content displayed in the Bottom_Sheet when a Heatmap_Zone is tapped, including aggregate counts and a request list
- **ReliefRequest**: A data record with fields: id, type (medical/food/rescue/shelter), description, peopleCount, locationText, priority (critical/high/medium/low), status (pending/inProgress/completed)
- **Request_List**: A scrollable list of ReliefRequests shown within the Zone_Summary
- **Detail_Screen**: The existing request detail screen that displays full information for a single ReliefRequest
- **Priority**: One of four severity levels assigned to a ReliefRequest: critical, high, medium, or low
- **Type**: One of four categories assigned to a ReliefRequest: medical, food, rescue, or shelter

## Requirements

### Requirement 1: Heatmap Zone Tap Detection

**User Story:** As a disaster relief coordinator, I want to tap a heatmap zone on the map, so that I can quickly see what requests are concentrated in that area.

#### Acceptance Criteria

1. WHEN the Map is displayed at a zoom level below 13, THE Map SHALL render Heatmap_Zones as tappable regions
2. WHEN a user taps a Heatmap_Zone, THE Map SHALL identify all ReliefRequests whose coordinates fall within that zone's geographic boundary
3. WHEN a user taps a Heatmap_Zone that contains at least one ReliefRequest, THE Map SHALL open the Bottom_Sheet displaying the Zone_Summary for that zone
4. IF a user taps a Heatmap_Zone that contains zero ReliefRequests, THEN THE Map SHALL not open the Bottom_Sheet
5. WHEN the Map is displayed at zoom level 13 or above, THE Map SHALL not treat Heatmap_Zones as tappable (pins are shown instead)

### Requirement 2: Zone Summary Aggregate Display

**User Story:** As a disaster relief coordinator, I want to see a breakdown of requests in a tapped zone, so that I can assess the overall situation at a glance before drilling into individual requests.

#### Acceptance Criteria

1. WHEN the Bottom_Sheet opens for a Heatmap_Zone, THE Zone_Summary SHALL display the total count of ReliefRequests within that zone
2. WHEN the Bottom_Sheet opens for a Heatmap_Zone, THE Zone_Summary SHALL display the count of ReliefRequests for each Type: medical, food, rescue, and shelter
3. WHEN the Bottom_Sheet opens for a Heatmap_Zone, THE Zone_Summary SHALL display the count of ReliefRequests for each Priority: critical, high, medium, and low
4. WHEN a Type has a count of zero for the tapped zone, THE Zone_Summary SHALL display that Type with a count of zero rather than omitting it
5. WHEN a Priority has a count of zero for the tapped zone, THE Zone_Summary SHALL display that Priority with a count of zero rather than omitting it

### Requirement 3: Zone Request List

**User Story:** As a disaster relief coordinator, I want to see the individual requests within a zone, so that I can identify specific needs and act on them.

#### Acceptance Criteria

1. WHEN the Bottom_Sheet opens for a Heatmap_Zone, THE Zone_Summary SHALL display a scrollable Request_List of all ReliefRequests within that zone
2. THE Request_List SHALL display each ReliefRequest showing at minimum: type, priority, description (truncated to 2 lines), and peopleCount
3. THE Request_List SHALL order ReliefRequests by priority, with critical first, then high, then medium, then low
4. WHEN the Request_List contains more items than fit in the visible Bottom_Sheet area, THE Bottom_Sheet SHALL allow the user to scroll through the Request_List
5. WHEN the aggregate summary and the Request_List are both visible, THE Zone_Summary SHALL keep the aggregate counts fixed at the top while the Request_List scrolls independently beneath them

### Requirement 4: Navigate to Request Detail

**User Story:** As a disaster relief coordinator, I want to tap a request in the zone summary list, so that I can view its full details and take action.

#### Acceptance Criteria

1. WHEN a user taps a ReliefRequest item in the Request_List, THE Bottom_Sheet SHALL navigate the user to the Detail_Screen for that ReliefRequest
2. WHEN the Detail_Screen is dismissed, THE Map SHALL return to the state it was in when the Bottom_Sheet was open
3. WHEN a user taps a ReliefRequest item in the Request_List, THE Bottom_Sheet SHALL remain dismissible via a downward swipe or tapping outside the sheet

### Requirement 5: Bottom Sheet Dismissal

**User Story:** As a disaster relief coordinator, I want to dismiss the zone summary, so that I can return to browsing the full map.

#### Acceptance Criteria

1. WHEN the Bottom_Sheet is open, THE Bottom_Sheet SHALL be dismissible by the user swiping it downward
2. WHEN the Bottom_Sheet is open, THE Bottom_Sheet SHALL be dismissible by the user tapping the Map area outside the sheet
3. WHEN the Bottom_Sheet is dismissed, THE Map SHALL restore full interactive access to the Map without any residual overlay
4. WHEN the Bottom_Sheet is open, THE Map SHALL remain pannable and zoomable behind the sheet in the area not covered by the sheet

### Requirement 6: Data Consistency

**User Story:** As a disaster relief coordinator, I want the zone summary to reflect current request data, so that I am not acting on stale information.

#### Acceptance Criteria

1. WHEN a Heatmap_Zone is tapped, THE Zone_Summary SHALL derive its counts and Request_List from the same in-memory dataset currently rendered on the Map
2. IF the app is operating in offline mode when a Heatmap_Zone is tapped, THEN THE Zone_Summary SHALL display data from the locally cached Hive dataset and THE Zone_Summary SHALL indicate to the user that the data may not be current
3. THE Zone_Summary SHALL display the same set of ReliefRequests that are currently visible given the active filter chips (Live Signals, Shelters, Supplies, Medical, Rescue)
