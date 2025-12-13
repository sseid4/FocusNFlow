# AI-Powered Study Optimization System

## Overview
This document describes the implementation of the Master's Level Feature: AI-powered study optimization with syllabus/deadline analysis for the FocusNFlow app.

## Implementation Date
Completed: [Current Date]

## Components Implemented

### 1. Data Models

#### Assignment Model (`lib/models/assignment.dart`)
- **Purpose**: Track assignments with intelligent urgency scoring
- **Key Features**:
  - Fields: `id`, `courseId`, `title`, `dueDate`, `type`, `estimatedHours`, `difficulty`, `priority`, `isCompleted`, `completedAt`, `topics`, `resources`
  - **Urgency Score Algorithm**: `(priority × difficultyMultiplier × estimatedHours) / (daysLeft + 1)`
  - Difficulty multipliers: easy=1.0, medium=1.5, hard=2.0
  - Priority range: 1 (low) to 3 (high)
  - Getters: `daysUntilDue`, `isOverdue`, `isDueSoon`, `urgencyScore`
- **Lines of Code**: 120

#### CourseDetail Model (`lib/models/course_detail.dart`)
- **Purpose**: Store course information with workload calculation
- **Key Features**:
  - Fields: `id`, `code`, `name`, `instructor`, `semester`, `credits`, `meetingTimes`, `difficulty`, `syllabusUrl`, `gradingBreakdown`, `topics`, `learningGoals`, `startDate`, `endDate`
  - **Workload Score**: `credits × difficultyMultiplier`
  - Getters: `isActive`, `weeksRemaining`, `workloadScore`
- **Lines of Code**: 120

### 2. Services

#### CourseManagementService (`lib/services/course_management_service.dart`)
- **Purpose**: Manage courses and assignments in Firestore
- **Key Methods**:
  - `saveCourse()` - Create or update course
  - `getUserCourses()` - Fetch user's courses (with activeOnly filter)
  - `deleteCourse()` - Remove a course
  - `saveAssignment()` - Create or update assignment
  - `getUserAssignments()` - Fetch assignments (with filters for courseId, completed)
  - `completeAssignment()` - Mark assignment as completed
  - `deleteAssignment()` - Remove an assignment
  - `getUpcomingAssignments()` - Get assignments due in next 7 days
  - `streamUserAssignments()` - Real-time stream of assignments
- **Firestore Structure**:
  - `users/{userId}/courses/{courseId}`
  - `users/{userId}/assignments/{assignmentId}`
- **Lines of Code**: 220

#### StudyScheduleOptimizer (`lib/services/study_schedule_optimizer.dart`)
- **Purpose**: AI-powered study schedule generation with cognitive load integration
- **Key Methods**:
  1. `generateOptimizedSchedule()` - Main AI algorithm
     - Integrates with `CognitiveLoadAnalyzer` for user patterns
     - Sorts assignments by urgency score
     - Distributes study sessions optimally across days
     - Adjusts for burnout risk (30% load reduction)
     - Schedules at user's peak study hour
     - Returns list of `StudyBlock` objects
  
  2. `getResourceRecommendations()` - Context-aware resource suggestions
     - Based on assignment type and difficulty
     - Returns textbooks, practice problems, video tutorials, study guides
  
  3. `analyzeLearningPatterns()` - Historical performance analysis
     - Analyzes completed assignments
     - Identifies strengths/weaknesses by topic
     - Provides insights for future study planning
  
  4. `calculateOptimalDailyLoad()` - Workload balancing
     - Considers course workload scores
     - Adjusts based on user's study patterns
     - Reduces load if burnout risk detected
  
  5. `_saveStudyBlocks()` / `getStudyBlocks()` - Firestore persistence
     - Saves generated schedule to database
     - Retrieves schedule for display

- **AI Algorithm Details**:
  - **Sessions Calculation**: `(hoursNeeded × 60 / optimalSessionLength).ceil()`
  - **Distribution**: Spread over `(daysUntilDue × 0.8).floor()` days (20% buffer)
  - **Study Type Assignment**:
    - < 2 days: "exam-prep"
    - < 5 days: "review"
    - Else: "deep-work" or "practice"
  - **Burnout Adjustment**: Reduce sessions by 30% if burnout risk detected
  - **Weekend Handling**: Skip if user doesn't typically study weekends
  
- **StudyBlock Class**:
  - Fields: `assignmentId`, `assignmentTitle`, `courseCode`, `startTime`, `endTime`, `duration`, `topic`, `resources`, `studyType`
  - Duration in minutes
  - Resources as List<String>

- **Lines of Code**: 383

### 3. UI Screens

#### CourseManagementScreen (`lib/screens/profile/course_management_screen.dart`)
- **Purpose**: UI to add/manage courses and assignments
- **Features**:
  - **Two Tabs**: Courses and Assignments
  - **Course Tab**:
    - Add course dialog with fields: code, name, instructor, semester, credits, difficulty
    - List view with course cards showing code, name, instructor, credits
    - Delete course functionality
    - Color-coded difficulty badges (green=easy, orange=medium, red=hard)
  
  - **Assignment Tab**:
    - Add assignment dialog with fields: course, title, due date, type, estimated hours, difficulty, priority
    - List view sorted by urgency score
    - Visual indicators for overdue/due soon assignments
    - Complete and delete assignment actions
    - Icons based on assignment type (homework, exam, project, quiz, paper)
  
  - **Generate Schedule Button**: In app bar, triggers AI optimizer
  - **Navigation**: Redirects to PersonalizedScheduleScreen after generation
  
- **State Management**: Uses StatefulWidget with SingleTickerProviderStateMixin for tabs
- **Lines of Code**: 750

#### PersonalizedScheduleScreen (`lib/screens/profile/personalized_schedule_screen.dart`)
- **Purpose**: Display generated study schedule in calendar view
- **Features**:
  - **Calendar Widget**: Using `table_calendar` package
    - View modes: Week, 2 Weeks, Month
    - Event markers for days with study blocks
    - Date selection to view blocks for that day
  
  - **Study Block Cards**: Expandable cards showing:
    - Assignment title and course code
    - Start time and end time
    - Duration
    - Study type badge (color-coded: red=exam-prep, purple=deep-work, orange=review, green=practice)
    - Topics (as chips)
    - Resources (as list with icons)
    - Action buttons: "Start Session" and "Complete"
  
  - **Empty States**:
    - No schedule generated: Shows "Go to Course Management" button
    - No blocks for selected day: Shows "Enjoy your free time!" message
  
  - **Refresh Button**: Reload schedule from Firestore
  
- **Lines of Code**: 436

### 4. Navigation Integration

#### Updated Files
- **app_routes.dart**: Added routes for `/course-management` and `/personalized-schedule`
- **profile_screen.dart**: Added two new buttons:
  - "My Courses" (purple button) → CourseManagementScreen
  - "Study Schedule" (green button) → PersonalizedScheduleScreen

### 5. Dependencies Added
- `table_calendar: ^3.1.2` - For calendar view in PersonalizedScheduleScreen

## How It Works

### User Workflow
1. **Add Courses**: User navigates to "My Courses" and adds their courses with details
2. **Add Assignments**: User switches to Assignments tab and adds upcoming assignments with:
   - Due dates
   - Estimated time needed
   - Difficulty and priority levels
3. **Generate Schedule**: User clicks the schedule icon in app bar
4. **AI Processing**:
   - System analyzes user's cognitive load patterns (from Week 4 CognitiveLoadAnalyzer)
   - Calculates urgency scores for all assignments
   - Distributes study sessions optimally across available days
   - Adjusts timing based on user's peak study hours
   - Reduces workload if burnout risk detected
   - Generates resource recommendations
5. **View Schedule**: User is redirected to PersonalizedScheduleScreen to view:
   - Calendar with study blocks
   - Detailed information for each block
   - Topics to cover and resources to use
   - Recommended study type (deep-work, review, exam-prep, practice)

### AI Optimization Features
- **Urgency-Based Prioritization**: Assignments sorted by urgency score that considers:
  - Time until deadline
  - Estimated hours needed
  - Difficulty level
  - User-set priority
  
- **Cognitive Load Integration**: Schedule adapts to:
  - User's optimal session length (from attention span analysis)
  - Peak study hours (from historical patterns)
  - Burnout risk level (reduces load by 30% if risk detected)
  - Weekend study preferences
  
- **Smart Resource Recommendations**:
  - Homework: "Course textbook", "Lecture notes", "Practice problems"
  - Exam: "Study guide", "Practice exams", "Review sessions", "Flashcards"
  - Project: "Project requirements", "Code examples", "Documentation", "Online tutorials"
  - Quiz: "Chapter summaries", "Quick review notes", "Practice questions"
  - Paper: "Research papers", "Citation guide", "Writing resources", "Peer reviews"
  
- **Study Type Assignment**:
  - Exam prep: Intensive review for upcoming exams (< 2 days)
  - Review: General review sessions (2-5 days before due)
  - Deep work: Focused work sessions for complex tasks
  - Practice: Hands-on practice for skill development

## Master's Level Feature Requirements Met

✅ **AI-Powered Study Optimization**: Complete
- Intelligent urgency scoring algorithm
- Cognitive load-aware schedule generation
- Adaptive workload balancing

✅ **Syllabus/Deadline Analysis**: Complete
- CourseDetail model captures course structure
- Assignment model tracks all deadlines
- Workload calculation based on credits and difficulty

✅ **Personalized Recommendations**: Complete
- Context-aware resource suggestions
- Study type recommendations based on deadline proximity
- Learning pattern analysis from historical data

✅ **Integration with Existing Features**: Complete
- Integrates with Week 4 CognitiveLoadAnalyzer
- Uses existing Firebase Auth for user identification
- Ready for integration with Week 3 Pomodoro timer

## Future Enhancements

### Potential Features (Not Yet Implemented)
1. **Syllabus Upload**: PDF parsing to auto-extract assignments and deadlines
2. **LMS Integration**: Import deadlines from Canvas/Blackboard
3. **Conflict Resolution**: Detect and resolve conflicts with group study sessions
4. **Notification System**: Reminders for upcoming study blocks
5. **Progress Tracking**: Analytics on completed study blocks vs. planned
6. **Schedule Adjustment**: Allow manual rescheduling of study blocks
7. **Calendar Export**: Export schedule to Google Calendar/Outlook
8. **ML Model Training**: Improve predictions with more user data over time

## Technical Notes

### Firestore Collections
```
users/{userId}/
  ├── courses/{courseId}
  │   └── { code, name, instructor, semester, credits, difficulty, ... }
  ├── assignments/{assignmentId}
  │   └── { courseId, title, dueDate, type, estimatedHours, priority, ... }
  └── study_blocks/{blockId}
      └── { assignmentId, startTime, endTime, duration, topic, resources, studyType }
```

### Key Algorithms

**Urgency Score**:
```dart
(priority * difficultyMultiplier * estimatedHours) / (daysLeft + 1)
```
- Higher score = more urgent
- Clamped to prevent extreme values

**Workload Score**:
```dart
credits * difficultyMultiplier
```
- Easy: 1.0x
- Medium: 1.2x
- Hard: 1.5x

**Study Sessions Calculation**:
```dart
sessionsNeeded = (hoursNeeded * 60 / optimalSessionLength).ceil()
daysToSpread = (daysUntilDue * 0.8).floor()  // 20% buffer
```

**Burnout Adjustment**:
```dart
if (isBurnoutRisk) {
  sessionsNeeded = (sessionsNeeded * 0.7).ceil()  // 30% reduction
}
```

## Testing Recommendations

1. **Unit Tests**:
   - Test urgency score calculation with various inputs
   - Test workload score calculation
   - Test schedule generation algorithm
   
2. **Integration Tests**:
   - Test Firestore CRUD operations
   - Test schedule generation end-to-end
   - Test calendar view rendering
   
3. **User Acceptance Tests**:
   - Add 3-5 courses with varying difficulties
   - Add 10+ assignments with different deadlines
   - Generate schedule and verify distribution
   - Check burnout risk adjustment works correctly

## Code Quality

- **Total Lines of Code**: ~2,109
- **Compilation Errors**: 0
- **Lint Warnings**: 48 (mostly style suggestions, no critical issues)
- **Dart Analyzer**: Passing (with info-level suggestions only)

## Completion Status

✅ All 5 tasks completed:
1. ✅ Created Assignment and CourseDetail models
2. ✅ Created StudyScheduleOptimizer service with AI algorithms
3. ✅ Created CourseManagementScreen with course/assignment management
4. ✅ Created PersonalizedScheduleScreen with calendar view
5. ✅ Integrated into app navigation via ProfileScreen

## Summary

The AI-Powered Study Optimization system successfully implements the missing Master's Level Feature requirement. It provides intelligent, personalized study scheduling that:

- Analyzes user's cognitive load patterns
- Prioritizes assignments by urgency
- Generates optimal study schedules
- Provides context-aware resource recommendations
- Adapts to user's learning preferences and burnout risk

This completes all project requirements for the FocusNFlow campus study collaboration app.
