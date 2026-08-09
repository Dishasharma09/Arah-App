# TASK 1: SMART MATCHING ALGORITHM PLAN

## Objective
Implement skill/experience-based matching between users and relevant opportunities/tasks.
The system should return appropriate users/tasks based on relevance.
Less-experienced users should appear higher in results where the matching logic is intended to prioritize opportunities for less-experienced users.

## Step 1: Inspect Existing Data
**Where matching data is stored:**
- User skills: `UserModel.skills` (List<String>)
- User experience: `UserModel.experienceLevel` (String: "Beginner" | "Intermediate" | "Advanced") 
- User mode: `UserModel.currentMode` (String: "Buyer" | "Seller") and `UserModel.role` (String: "Buyer" | "Seller" | "Both")
- Task category: `TaskModel.category` (String)
- Task tags: `TaskModel.tags` (List<String>)
- Task beginner-friendly flag: `TaskModel.isBeginnerFriendly` (boolean)
- Task price: `TaskModel.price` (String)

**Missing data for optimal matching:**
- User dateOfBirth (for precise age calculation)
- User country (for location-based matching)
- Task skill requirements (explicit skills needed for task)
- Task experience requirements (min/max experience level)
- Task budget range (min/max budget)

## Step 2: Design Matching Algorithm

**Scoring System:**
Match Score = (Skill Compatibility × 0.4) + (Experience Compatibility × 0.3) + (Category Compatibility × 0.2) + (Beginner Priority × 0.1)

Where:
- **Skill Compatibility (0-1):** Jaccard similarity between user skills and task-relevant skills
  - For now, use task.tags as proxy for skill requirements
  - Future: when task.skillRequirements field added, use that
  - Formula: |A � ∩ B| / |A � ∪ B| where A=user skills, B=task tags
  
- **Experience Compatibility (0-1):** How well user experience matches task requirements
  - Current: based on isBeginnerFriendly flag
  - Beginner user (0.0-0.33): prefers beginner-friendly tasks
  - Intermediate user (0.34-0.66): flexible
  - Advanced user (0.67-1.0): may prefer non-beginner tasks
  - Future: when task.experienceMin/Max fields added, use precise mapping
  
- **Category Compatibility (0-1):** How well user interests match task category
  - Current: skill/category overlap
  - Simple: 1.0 if any user skill matches task category/tags, else 0.0
  - Future: more sophisticated interest mapping
  
- **Beginner Priority (0-1):** Bonus for less-experienced users
  - Beginner users: 1.0
  - Intermediate users: 0.5  
  - Advanced users: 0.0
  - This implements the requirement to prioritize opportunities for less-experienced users

**Score Range:** 0.0 to 1.0 (higher = better match)

## Step 3: Define Ranking
- **Highest relevance:** Score closest to 1.0
- **Experience priority:** Beginner users get bonus in scoring (Beginner Priority factor)
- **Skill matching:** Direct skill overlap increases score
- **Missing skills:** Lower skill compatibility score
- **Incompatible users:** Low experience or category compatibility
- **Tie-breaking:** 
  1. Higher score
  2. Newer tasks first (createdAt descending)
  3. Alphabetical by title
- **Users with incomplete profiles:** 
  - Missing skills: skill compatibility = 0
  - Missing experienceLevel: treat as Intermediate (0.5)
  - Missing currentMode/role: assume Buyer for safety

## Step 4: Performance Considerations
- **Avoid downloading entire Users collection:** Matching is task-centric - for a given user, find matching tasks
- **Firestore queries:** 
  - Can filter by status = 'open' 
  - Exclude user's own tasks (buyerId != userId)
  - Cannot do complex computations in Firestore queries
- **Solution:** Cloud Function that does the computation
- **Indexes needed:** 
  - tasks: status, buyerId (for excluding own tasks)
  - Consider composite indexes for common query patterns
- **Pagination:** Return limited results (e.g., 20) with continuation token
- **Caching:** Consider caching results for short period (5-10 mins) for same user

## Step 5: Security
- **Prevent manipulation:** 
  - All scoring done in secure Cloud Function
  - User cannot affect scoring algorithm
  - Input validation on userId parameter
  - Only return tasks user is authorized to see (status = 'open', not own tasks)
- **Data validation:** Validate userId format, check user exists
- **Rate limiting:** Consider adding to prevent abuse

## Step 6: Implementation Approach
1. Create new Cloud Function: `smartMatchTasks`
2. Create corresponding Firestore indexes
3. Add method to FirestoreService to call the function
4. Add method to HomeProvider to use smart matching instead of basic filtering
5. Update security rules if needed (should be readable by authenticated users)
6. Test thoroughly

## Step 7: Testing Plan
Test cases:
- Exact skill match
- Partial skill match  
- No skill match
- Beginner user with beginner-friendly task
- Beginner user with advanced task
- Experienced user with beginner task
- Experienced user with advanced task
- User with missing skills/experience
- Task with missing tags/category
- Large result set pagination
- Unauthorized access attempts

## Expected Changes
**Files to modify:**
1. functions/index.js - add smartMatchTasks Cloud Function
2. firestore.indexes.json - add required indexes
3. lib/services/firestore_service.dart - add smart matching service method
4. lib/provider/home_provider.dart - integrate smart matching
5. lib/models/task_model.dart - optional: add skillRequirements/experienceMinMax fields (for future)
6. lib/models/user_model.dart - optional: add dateOfBirth/country fields (for future, Task 5)

**Note:** We'll implement with existing fields first, then enhance in later tasks when we add missing fields.

## Integration Points for Frontend
**Function:** smartMatchTasks (Callable Cloud Function)
**Input:** { userId: string, limit: number (optional), lastTaskId: string (optional for pagination) }
**Output:** {
  matches: [
    {
      taskId: string,
      score: number (0-1),
      task: TaskModel,
      matchBreakdown: {
        skillCompatibility: number,
        experienceCompatibility: number, 
        categoryCompatibility: number,
        beginnerPriority: number
      }
    }
  ],
  lastTaskId: string (for pagination),
  hasMore: boolean
}

**Alternative approach:** Add method to HomeProvider that uses the Cloud Function and updates the task list.

## Dependencies
- None - uses existing data structures
- Enhances existing fetchOpenTasksExcluding functionality
- Does not break existing filtering (search, category, budget) - can apply after matching