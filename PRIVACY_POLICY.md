# Privacy Policy for Spor

**Effective Date:** October 14, 2026  
**Application:** Spor (`com.spor.mobile`)  
**Developer:** gwj0323  

---

> [!NOTE]
> **Independent Disclaimer:** Spor is an independent public transit companion application. Spor utilizes open transit timetable endpoints (Rejseplanen open data) and is not affiliated with, endorsed by, or operated by Rejseplanen A/S or DSB.

---

## 1. Overview
Your privacy is of utmost importance. Spor is designed with a privacy-first approach: we do not require account registration, we do not track your identity, and we do not sell or monetize your personal data.

## 2. Information We Access and How It Is Used
- **Location Data (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`)**:
  When you explicitly tap the "Locate nearest station" button, Spor queries your device's GPS coordinates to find stations and stops closest to you. Location coordinates are transmitted directly to the transit API over HTTPS solely to retrieve nearby stations. **Your location is never stored on any remote server, tracked in the background, or shared with third parties.**
- **Notifications & Alarms (`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`)**:
  Used strictly on-device to notify you when you explicitly schedule a trip departure reminder, transfer alert, or arrival notification. These alarms are managed locally on your device via the Android alarm manager.
- **Calendar Integration**:
  Used strictly when you tap "Export to Calendar" to insert your selected itinerary and travel timetable into your personal device calendar via the system calendar app. We do not access, read, transmit, or analyze your other calendar entries.

## 3. Third-Party Services & Analytics
Spor does not embed third-party advertising SDKs, behavioral analytics trackers, or commercial profiling libraries. Public transit timetables and real-time departure boards are retrieved via HTTPS directly from open transit data endpoints.

## 4. Data Retention & Security
All user preferences (such as favorite stations, recent searches, and UI theme options) are saved exclusively on your local device storage using standard sandboxed SharedPreferences. Clearing app data or uninstalling the app permanently erases this data.

## 5. Contact
If you have any questions or concerns regarding this Privacy Policy, please open an issue on our GitHub repository: [github.com/gwj0323/spor-app](https://github.com/gwj0323/spor-app/issues).
