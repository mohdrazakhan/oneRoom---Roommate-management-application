# 🏷️ Custom Category Feature

## ✨ What's New

You can now create your own custom expense categories with personalized emojis!

## 🎯 How to Use

### Option 1: Enhanced Expense Screen
1. Open or create an expense
2. Find the **Category** dropdown
3. Scroll to the bottom and select **"Create Custom Category..."**
4. Enter:
   - **Category Name**: e.g., "Pet Care", "Gifts", "Medical", etc.
   - **Emoji Icon**: Choose any emoji (🐕, 🎁, 💊, etc.)
5. Tap **Create**
6. Your custom category is now selected!

### Option 2: Bottom Sheet (Quick Add)
1. Tap the **+** button to add expense
2. In the Category section, tap the **"Custom"** chip
3. Enter category name and emoji
4. Tap **Create**
5. Done!

## 💡 Examples

Here are some custom category ideas:

- 🐕 **Pet Care** - Food, vet, grooming
- 🎁 **Gifts** - Birthdays, holidays
- 💊 **Medical** - Medicines, doctor visits
- 📚 **Books** - Books, magazines
- 🎮 **Gaming** - Games, subscriptions
- ☕ **Coffee** - Coffee shop visits
- 🌿 **Plants** - Garden, indoor plants
- 🏋️ **Fitness** - Gym, sports equipment
- 🎨 **Hobbies** - Art supplies, crafts
- 🚗 **Car Care** - Maintenance, fuel
- 📱 **Tech** - Gadgets, accessories
- 🧴 **Personal Care** - Toiletries, cosmetics
- 🎓 **Education** - Courses, training
- 🏖️ **Vacation** - Travel, trips
- 🎪 **Events** - Concerts, shows

## 📝 Technical Details

- Custom categories are saved with the expense
- The default emoji is 🏷️ if you don't choose one
- Custom categories persist across sessions
- They display just like built-in categories
- No limit on the number of custom categories

## 🔍 Where Custom Categories Appear

Your custom categories will show:
- ✅ In the expense detail screen
- ✅ In the expense list
- ✅ In category filters
- ✅ In analytics/summaries
- ✅ When editing the expense

## 💾 Data Storage

Custom categories are stored as simple strings in Firestore:
```json
{
  "category": "Pet Care",
  // ... other expense fields
}
```

The emoji and color are managed by the `ExpenseCategory.getCategory()` helper, which:
- Returns predefined categories if they match
- Creates a custom category on-the-fly for unknown names
- Uses a default grey color for custom categories

## 🎨 Customization Tips

1. **Keep names short** - They'll display better in the UI
2. **Use descriptive emojis** - They make categories easy to spot
3. **Be consistent** - Use the same name/emoji combo each time
4. **Group related expenses** - e.g., all pet expenses under "Pet Care"

## 🚀 Future Enhancements

Potential improvements:
- Save custom categories to user preferences
- Auto-suggest from previously used custom categories
- Color picker for custom categories
- Category usage statistics
- Bulk category editing

---

**Enjoy organizing your expenses your way!** 🎉
