# Modern Expense Management - Feature Documentation

## 🎨 Overview

The new **Modern Expense Screen** provides a completely redesigned, intuitive interface for managing expenses in your roommate app. Based on modern UI/UX principles, it offers advanced splitting options, bill image attachments, and seamless editing capabilities.

## ✨ Key Features

### 1. **Modern, Clean UI**
- ✅ Clean white background with intuitive layout
- ✅ Large, touch-friendly buttons and inputs
- ✅ Visual feedback for all interactions
- ✅ Smooth animations and transitions
- ✅ Follows Material Design 3 principles

### 2. **Bill Image Attachment**
- ✅ **Camera capture**: Take photos of bills directly
- ✅ **Gallery upload**: Choose existing images
- ✅ **Image preview**: See uploaded bills before saving
- ✅ **Remove option**: Easy removal of attached images
- ✅ **Cloud storage**: Images saved to Firebase Storage
- ✅ **Automatic optimization**: Images resized to 1920x1920 at 85% quality

### 3. **Advanced Split Options**

#### **Equal Split** (Default)
- Automatically divides expense equally among selected members
- Real-time calculation as you select/deselect members
- Shows individual amounts for each person

#### **Percentage Split**
- Define custom percentages for each member
- Visual percentage input with validation
- Must total 100% before saving
- Shows equivalent amounts in rupees
- Great for situations where contribution isn't equal

#### **Custom Amount Split**
- Enter exact amounts for each person
- Useful for complex splitting scenarios
- Flexible for any splitting arrangement

### 4. **Edit Expense**
- Full editing capability for existing expenses
- Pre-populated fields with current data
- All features available during editing
- Update bill images
- Change split configurations

### 5. **Enhanced User Experience**
- **Member selection**: Visual avatars with colored circles
- **Category selection**: Icon-based category chips
- **Date picker**: Easy date modification
- **Notes field**: Optional additional information
- **Paid by selector**: Clear indication of who paid
- **Real-time calculations**: See split amounts as you type

---

## 🚀 How to Use

### Adding a New Expense

1. **Open Expense List**
   - Navigate to your room
   - Tap the "Add Expense" floating button

2. **Add Bill Image** (Optional)
   - Tap **Camera** to take a photo, OR
   - Tap **Gallery** to select from photos
   - Preview shows immediately
   - Tap ❌ to remove if needed

3. **Enter Basic Information**
   - **Title**: What was purchased (e.g., "Groceries", "Electricity Bill")
   - **Amount**: Total expense amount in rupees
   - **Category**: Select from predefined categories (Food, Utilities, etc.)

4. **Select Who Paid**
   - Choose the member who paid for this expense
   - Tap on their name/avatar

5. **Configure Split**
   - **Default**: All members selected with equal split
   - Tap "Split Type" to change split method:
     - **Equal Split**: Everyone pays the same
     - **Percentage**: Define custom percentages
     - **Custom Amount**: Enter exact amounts

6. **For Percentage/Custom Splits**:
   - Tap "Split Type" button
   - Select your preferred method
   - Enter percentages or amounts for each member
   - For percentages: Must total 100%
   - Tap "DONE" when finished

7. **Set Date** (Optional)
   - Tap on the date field
   - Choose the expense date
   - Defaults to today

8. **Add Notes** (Optional)
   - Add any additional information
   - Great for details or reminders

9. **Save**
   - Tap "SAVE" in the top right
   - Expense is added to the room
   - All members can see it immediately

### Editing an Existing Expense

1. **Open Expense Details**
   - Tap on any expense in the list
   - View full details

2. **Tap Edit Icon** (✏️)
   - Located in the top right of detail screen

3. **Modify Any Fields**
   - All fields are editable
   - Change split configuration
   - Update bill image
   - Modify amounts or categories

4. **Save Changes**
   - Tap "SAVE"
   - Changes reflected immediately

---

## 📸 Bill Image Feature

### Supported Operations
- ✅ Take photo with camera
- ✅ Select from gallery
- ✅ Preview before upload
- ✅ Remove/replace images
- ✅ View in expense details

### Technical Details
- **Storage**: Firebase Storage
- **Path**: `expenses/{roomId}/{timestamp}.jpg`
- **Max dimensions**: 1920x1920 pixels
- **Quality**: 85% compression
- **Format**: JPEG

### Firebase Storage Rules Required

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /expenses/{roomId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null 
                   && request.resource.size < 10 * 1024 * 1024 // 10MB max
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

---

## 🔢 Split Type Details

### 1. Equal Split
**When to use**: Most common scenarios where everyone shares equally

**Example**:
- Total: ₹300
- 3 people selected
- Each pays: ₹100

**How it works**:
- Amount ÷ Number of selected members
- Automatically recalculates when members are selected/deselected

---

### 2. Percentage Split
**When to use**: Different contribution levels based on usage/agreement

**Example**:
- Total: ₹1000
- Amit: 40% (₹400)
- Pranyush: 35% (₹350)
- Raza: 25% (₹250)

**How it works**:
- Enter percentage for each member
- Must total exactly 100%
- Shows equivalent rupee amount
- Validates before saving

**Validation**:
- ✅ Total = 100%: Green checkmark
- ❌ Total ≠ 100%: Red indicator, can't save

---

### 3. Custom Amount Split
**When to use**: Complex scenarios with specific amounts

**Example**:
- Total: ₹500
- Amit owes: ₹200
- Pranyush owes: ₹150
- Raza owes: ₹150

**How it works**:
- Enter exact amount for each person
- No validation required
- Maximum flexibility

**Use cases**:
- Shared items with different quantities
- Partial payments
- Special arrangements

---

## 🎨 UI Components

### Categories
- 🍔 **Food**: Restaurant meals, groceries
- 🛒 **Groceries**: Supermarket shopping
- ⚡ **Utilities**: Electricity, water, gas, internet
- 🏠 **Rent**: Monthly rent payments
- 🚗 **Transport**: Fuel, public transport, parking
- 🎬 **Entertainment**: Movies, games, subscriptions
- 🧹 **Cleaning**: Cleaning supplies, services
- 📦 **Other**: Anything else

### Color Scheme
- **Primary**: Orange (#FF9800)
- **Selected items**: Orange background
- **Inactive**: Grey (#F5F5F5)
- **Text**: Black/Grey hierarchy
- **Avatars**: Orange circles with white initials

---

## 🔧 Technical Implementation

### File Structure
```
lib/screens/expenses/
├── modern_expense_screen.dart   (NEW - Main screen)
├── expense_detail_screen.dart   (UPDATED - Now uses modern screen for editing)
└── expenses_list_screen.dart    (UPDATED - Uses modern screen for adding)
```

### Key Components

#### 1. **ModernExpenseScreen**
- Main widget handling add/edit
- Manages all form state
- Handles image upload
- Calculates splits

#### 2. **Split Type Dialog**
- Bottom sheet for selecting split method
- Visual selection with icons
- Immediate feedback

#### 3. **Custom Split Dialog**
- Scrollable member list
- Individual input fields
- Real-time total calculation
- Percentage validation

#### 4. **Bill Image Section**
- Camera/Gallery selection
- Image preview
- Upload to Firebase Storage
- Error handling

### State Management
```dart
// Main state variables
String _splitType = 'equal';  // 'equal', 'percentage', 'custom'
Map<String, double> _customSplits = {};
Set<String> _selectedMembers = {};
File? _billImageFile;
String? _billImageUrl;
```

### Split Calculation Logic
```dart
Map<String, double> _calculateSplits(double amount) {
  if (_splitType == 'equal') {
    final perPerson = amount / _selectedMembers.length;
    return {for (var uid in _selectedMembers) uid: perPerson};
  } 
  else if (_splitType == 'percentage') {
    return _customSplits.map((uid, percent) {
      return MapEntry(uid, (percent / 100) * amount);
    });
  } 
  else {
    return Map.from(_customSplits);
  }
}
```

---

## 🐛 Error Handling

### Image Upload Failures
- **Network errors**: Shown to user with retry option
- **Permission errors**: Clear message about Firebase rules
- **Size errors**: Images automatically compressed

### Split Validation
- **Empty selection**: Warning before save
- **Percentage total ≠ 100%**: Red indicator, save disabled
- **Missing amount**: Form validation

### Firestore Errors
- **Add failure**: Error message with details
- **Update failure**: Rollback to previous state
- **Network issues**: Retry mechanism

---

## 📱 Screenshots Reference

Based on your provided images, the UI includes:

1. **Clean expense form** with modern input fields
2. **Member selection** with avatars and names (Amit, Anshu, Pranyush, Raza)
3. **Split amount dialog** showing percentage/amount breakdown
4. **Category selection** with icons
5. **Date picker** integration
6. **Bill attachment** option

---

## 🔮 Future Enhancements

Potential additions for future versions:

- [ ] Multiple bill images per expense
- [ ] OCR for bill scanning (auto-fill amount)
- [ ] Recurring expenses
- [ ] Expense templates
- [ ] Export individual expense as PDF
- [ ] Split history tracking
- [ ] Expense analytics per person

---

## ⚠️ Important Notes

### Firebase Storage Configuration
**CRITICAL**: You must configure Firebase Storage rules to allow uploads. Without this, bill image uploads will fail.

Add these rules in **Firebase Console → Storage → Rules**:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /expenses/{roomId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null 
                   && request.resource.size < 10 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

### Permissions Required
- **Camera**: For taking bill photos
- **Gallery**: For selecting existing images
- **Internet**: For uploading to Firebase

### Data Persistence
- All expenses saved to Firestore
- Bill images stored in Firebase Storage
- Real-time sync across all devices
- Offline support via Firestore cache

---

## 📞 Support

If you encounter issues:

1. **Check Firebase Storage rules** (most common issue)
2. **Verify internet connection** for image uploads
3. **Check app permissions** for camera/gallery
4. **View error logs** in debug console

---

## 🎉 Summary

The Modern Expense Screen provides:

✅ **Intuitive UI** - Easy to understand and use  
✅ **Flexible splitting** - Equal, percentage, or custom amounts  
✅ **Bill attachments** - Camera or gallery with cloud storage  
✅ **Full editing** - Modify any expense anytime  
✅ **Real-time updates** - Instant sync across devices  
✅ **Professional design** - Modern, clean interface  

Enjoy the new expense management experience! 🚀
