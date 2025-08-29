# Clipboard - Personal Discovery & Tracking App

A modern iOS app built with SwiftUI that helps you organize and track your discoveries from social media, recipes, places to visit, and more.

## Features

### 🎯 Core Functionality
- **Smart Content Categorization**: Automatically categorizes content by type (places, recipes, restaurants, activities, shops)
- **Location Mapping**: View all your saved places on an interactive map
- **Rating System**: Rate places you've visited (1-5 stars)
- **Visit Tracking**: Mark items as visited/not visited
- **Favorites**: Mark your favorite discoveries
- **Tags & Notes**: Add custom tags and personal notes to any item

### 📱 User Interface
- **Tabbed Interface**: Easy navigation between List, Map, Categories, and Stats views
- **Search & Filter**: Find items quickly with search and type-based filtering
- **Modern Design**: Clean, intuitive interface with beautiful animations
- **Dark Mode Support**: Full support for light and dark themes

### 🔗 Share Extension
- **Easy Sharing**: Share links directly from other apps (TikTok, Instagram, YouTube, etc.)
- **Smart Parsing**: Automatically extracts information from shared URLs
- **Auto-Categorization**: Intelligently categorizes content based on the source

### 📊 Analytics
- **Statistics Dashboard**: View your discovery patterns
- **Progress Tracking**: See how many places you've visited vs. want to visit
- **Category Breakdown**: Understand your interests by content type

## Supported Platforms

- **TikTok**: Recipe videos and food content
- **Instagram**: Posts and stories
- **YouTube**: Recipe videos and travel content
- **Google Maps**: Location sharing
- **Yelp**: Restaurant recommendations
- **TripAdvisor**: Travel recommendations
- **Generic URLs**: Any web link with smart categorization

## How to Use

### Adding Items
1. **Manual Entry**: Tap the + button to add items manually
2. **Share Extension**: Use the share button in any app to send links directly to Clipboard
3. **URL Parsing**: Paste URLs and let the app automatically categorize them

### Organizing Content
1. **Categories**: Create custom categories to group related items
2. **Tags**: Add tags for easy searching and filtering
3. **Notes**: Add personal notes and memories to each item

### Tracking Progress
1. **Mark as Visited**: Toggle the visited status when you go somewhere
2. **Rate Experiences**: Give 1-5 star ratings to places you've visited
3. **View Statistics**: Check your progress in the Stats tab

### Map View
1. **Interactive Map**: See all your saved locations on a map
2. **Location Details**: Tap on map pins to view item details
3. **Navigation**: Use the map to plan your visits

## Technical Details

### Architecture
- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Persistent data storage
- **MapKit**: Location and mapping functionality
- **Share Extension**: iOS share sheet integration

### Data Models
- **ContentItem**: Main content model with metadata
- **Location**: Geographic location data
- **Category**: Custom categorization system

### Key Features
- **Automatic URL Parsing**: Extracts metadata from various platforms
- **Location Services**: Maps integration with coordinates
- **Search & Filter**: Real-time search with multiple filters
- **Data Persistence**: Local storage with SwiftData

## Setup Instructions

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0 or later
- Apple Developer Account (for device testing)

### Installation
1. Clone the repository
2. Open `Clipboard.xcodeproj` in Xcode
3. Select your development team in project settings
4. Build and run on your device or simulator

### Share Extension Setup
1. The Share Extension target is included in the project
2. Ensure both main app and extension have the same team ID
3. Test sharing from other apps to verify functionality

## Future Enhancements

### Planned Features
- **Cloud Sync**: iCloud integration for cross-device sync
- **Social Features**: Share discoveries with friends
- **Advanced Analytics**: More detailed insights and trends
- **Export/Import**: Backup and restore functionality
- **Notifications**: Reminders for places you want to visit
- **Offline Maps**: Download maps for offline use

### Potential Integrations
- **Apple Maps**: Deep integration with Apple's mapping service
- **Calendar**: Add visits to your calendar
- **Photos**: Attach photos to your discoveries
- **Reviews**: Integration with review platforms
- **Booking**: Direct booking for restaurants and activities

## Contributing

This is a personal project, but suggestions and improvements are welcome! Feel free to:
- Report bugs or issues
- Suggest new features
- Submit pull requests
- Share your experience using the app

## License

This project is for personal use and educational purposes.

---

**Built with ❤️ using SwiftUI and modern iOS development practices** 