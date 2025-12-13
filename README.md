# FocusNFlow

**AI-Powered Study Collaboration Platform for Georgia State University**

FocusNFlow is a mobile application that helps GSU students collaborate, manage their coursework, optimize study schedules, and maintain healthy cognitive loads through intelligent AI analytics.

## 🎯 Key Features

### Study Collaboration
- **Study Rooms Map** - Discover and locate available study rooms on campus with interactive map
- **Study Groups** - Find or create study groups and connect with peers
- **Real-time Chat** - Communicate with group members in real-time

### AI-Powered Scheduling
- **Intelligent Schedule Generator** - AI creates personalized study plans based on:
  - Course difficulty and credit hours
  - Assignment deadlines and priority
  - Your cognitive patterns and attention spans
  - Optimal session durations for your learning style
- **Interactive Calendar** - Visual study block planning with adjustable sessions

### Course Management
- **Course Tracker** - Track all your courses with grading breakdown
- **Assignment Management** - Organize assignments with urgency scoring algorithm
- **Progress Analytics** - Monitor your workload and study patterns

### Cognitive Health
- **Burnout Risk Detection** - Real-time alerts when stress levels are high
- **Study Pattern Analysis** - Understand your peak learning hours
- **Attention Span Monitoring** - Optimize session lengths for your focus window
- **Workload Balancing** - Auto-adjust study load to prevent cognitive overload

## 🏗️ Architecture

### Tech Stack
- **Frontend**: Flutter (Cross-platform: iOS, Android, Web)
- **Backend**: Firebase (Auth, Firestore, Cloud Functions)
- **Real-time**: Firestore Streams
- **Analytics**: Custom Cognitive Load Analyzer
- **Maps**: Flutter Map + OpenStreetMap
- **Calendar**: Table Calendar with custom study blocks

### Project Structure
```
lib/
├── core/              # App configuration (routes, theme, constants)
├── screens/           # UI screens organized by feature
│   ├── auth/         # Authentication screens
│   ├── home/         # Home dashboard
│   ├── map/          # Study rooms map
│   ├── groups/       # Study groups
│   ├── profile/      # User profile & analytics
│   └── chat/         # Real-time messaging
├── models/           # Data models (Assignment, Course, etc)
├── services/         # Business logic & Firebase integration
│   ├── study_schedule_optimizer.dart
│   ├── cognitive_load_analyzer.dart
│   └── course_management_service.dart
└── widgets/          # Reusable UI components
```

## 🚀 Getting Started

### Prerequisites
- Flutter 3.9.0+
- Dart 3.9.0+
- Firebase account with Firestore database
- Android SDK (for Android) or Xcode (for iOS)

### Installation
```bash
# Clone the repository
git clone https://github.com/sseid4/FocusNFlow.git
cd FocusNFlow/focus_flow

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Firebase Setup
1. Create a Firebase project at [firebase.google.com](https://firebase.google.com)
2. Enable Firestore Database, Authentication (Email/Password, Google Sign-In)
3. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
4. Place files in appropriate directories
5. Update `firebase_options.dart` with your Firebase configuration

## 📊 AI Algorithms

### Urgency Scoring (Assignments)
```
urgencyScore = (priority × difficultyMultiplier × estimatedHours) / (daysLeft + 1)
```
- **Priority**: 1-5 scale
- **Difficulty Multiplier**: 0.5 (easy) to 2.0 (very hard)
- **Result**: Color-coded urgency (Red: ≤2 days, Orange: ≤5 days, Green: later)

### Workload Balancing
```
workloadScore = credits × difficultyMultiplier
```
- Tracks total cognitive load across all courses
- Triggers burnout warnings when load exceeds safe threshold
- Recommends load reduction or study breaks

### Study Schedule Optimization
- Calculates optimal session duration based on attention span
- Spreads study blocks across days with 20% buffer
- Adjusts for high cognitive load (30% reduction if burnout risk)
- Recommends peak productivity hours based on study patterns

## 🎨 GSU Branding

- **Primary Color**: #0055B8 (GSU Blue)
- **Secondary Colors**: Purple, Green, Gold, Indigo for UI elements
- **Motto**: "Panther Rising to Success"

## 📱 Screens

| Screen | Purpose |
|--------|---------|
| **Home Dashboard** | Quick stats, upcoming assignments, study rooms map, quick actions |
| **Study Map** | Interactive map of campus study rooms |
| **Study Groups** | Browse and join study groups, real-time chat |
| **Course Manager** | Add/manage courses and assignments |
| **Study Schedule** | View AI-generated study plan on calendar |
| **Profile/Analytics** | View cognitive health metrics and study patterns |

## 🔧 Development

### Key Services

**StudyScheduleOptimizer**
- Generates personalized study schedules
- Considers course load, deadlines, and cognitive patterns
- Returns optimized study blocks with specific topics and resources

**CognitiveLoadAnalyzer**
- Analyzes study patterns from Firestore data
- Calculates attention spans and burnout risk
- Recommends optimal study session durations

**CourseManagementService**
- CRUD operations for courses and assignments
- Real-time Firestore streams
- Upcoming assignments filtering

### Data Models

**Assignment**
- Title, description, due date
- Type: homework, exam, project, quiz, paper
- Priority (1-5), estimated hours, completion status
- Auto-calculated urgency score

**CourseDetail**
- Code, name, instructor, semester
- Credit hours, difficulty level
- Grading breakdown, meeting times
- Learning goals and resources

**StudyBlock**
- Course reference, topic, date/time
- Session duration, study type (exam-prep, review, deep-work, practice)
- Resources and notes
- Completion status

## 🚧 Future Enhancements

- [ ] Syllabus PDF parsing for automatic deadline extraction
- [ ] LMS integration (Canvas, Blackboard)
- [ ] Push notifications for upcoming study blocks
- [ ] Calendar export to Google Calendar
- [ ] Peer study session matching
- [ ] Performance analytics dashboard with trends
- [ ] Offline mode support
- [ ] Mobile app store deployment (Apple App Store, Google Play)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with atomic commits
4. Push to your branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 👥 Team
- Emma Brown
- Siyam Seid

## 🙏 Acknowledgments
- Firebase for backend infrastructure
- Flutter community for excellent tools and documentation
- OpenStreetMap for map data
