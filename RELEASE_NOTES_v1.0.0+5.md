# OneRoom Release Notes - v1.0.0+5
Date: December 18, 2024

### 🚀 New Features
- **Guest Payment Lifecycle**: Full support for recording payments to and from guest users. Guests are no longer persistent in new expenses unless they have an active balance or are manually added.
- **Smart Settlements**: Integrated navigation from the suggested settlements list in Balances screen to the Record Payment screen with amount, payer, and receiver pre-filled.
- **Enhanced Room Navigation**: 
  - Tapping the balance chip navigates to the Balances screen.
  - Tapping the room icon navigates to Room Settings.
  - Tapping the new "Analytics" chip navigates to Expense Analytics.
- **Modernized UI**: Refreshed the Room Card action buttons with better icons and text that scales to fit various screen sizes without truncation.

### 🛠 Improvements
- Improved responsiveness of the Room Card on smaller devices.
- Added explicit (Guest) labeling in payment selection to distinguish from registered members.
- Guarded BuildContext across async gaps in subscription and expense screens.

### 🐛 Bug Fixes
- Fixed guest persistence bug where guests would appear in all new expenses once added.
- Resolved linting warnings related to unused variables and deprecated methods.
- Fixed potential crashes when navigating after dialog closures.
