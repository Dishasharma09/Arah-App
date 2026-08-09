$(head -n -2 /c/Users/EazyPC/OneDrive/Desktop/ARAH/Arah-App/Arah/functions/index.js)

// Callable function for smart matching between users and tasks
exports.smartMatchTasks = onCall(async (request) => {
  // Authenticate the request
  if (!request.auth) {
    throw new httpsError.HttpsError('unauthenticated', 'User must be authenticated to use smart matching');
  }

  const callerUid = request.auth.uid;
  const limit = request.data.limit || 20; // Default limit of 20 matches
  const lastTaskId = request.data.lastTaskId || null; // For pagination

  try {
    // Get the caller's user profile first
    const callerUserDoc = await db.collection('users').doc(callerUid).get();
    if (!callerUserDoc.exists) {
      throw new httpsError.HttpsError('not-found', 'Caller user not found');
    }

    const callerData = callerUserDoc.data();
    const callerSkills = callerData.skills || [];
    const callerExperienceLevel = callerData.experienceLevel || 'Intermediate'; // Default if missing
    const callerCurrentMode = callerData.currentMode || 'Buyer'; // Default if missing

    // Determine what type of tasks to match based on user mode
    // Buyers see tasks they can hire for (open tasks)
    // Sellers see tasks they can work on (open tasks)
    // Both mode users see open tasks
    // In all cases, we exclude tasks posted by the user themselves

    // Build base query for open tasks excluding user's own tasks
    let tasksQuery = db.collection('tasks')
      .where('status', '==', 'open')
      .where('buyerId', '!=', callerUid);

    // Apply pagination if lastTaskId is provided
    if (lastTaskId) {
      const lastTaskDoc = await db.collection('tasks').doc(lastTaskId).get();
      if (lastTaskDoc.exists) {
        tasksQuery = tasksQuery.startAfter(lastTaskDoc);
      }
    }

    // Limit the query to prevent loading too many documents
    // We'll fetch more than needed to account for filtering, but limit to reasonable amount
    const fetchLimit = Math.min(limit * 3, 100); // Fetch up to 3x limit or max 100
    tasksQuery = tasksQuery.limit(fetchLimit);

    // Execute the query
    const tasksSnapshot = await tasksQuery.get();

    if (tasksSnapshot.empty) {
      return {
        matches: [],
        lastTaskId: null,
        hasMore: false
      };
    }

    // Process each task to calculate match score
    const matchesWithScores = [];

    tasksSnapshot.forEach((taskDoc) => {
      const taskData = taskDoc.data();
      
      // Calculate skill compatibility (Jaccard similarity)
      const taskTags = taskData.tags || [];
      const taskCategory = taskData.category || '';
      
      // Combine tags and category for skill matching
      const taskSkillSet = new Set([...taskTags, taskCategory]);
      const callerSkillSet = new Set(callerSkills);
      
      let intersectionSize = 0;
      taskSkillSet.forEach(skill => {
        if (callerSkillSet.has(skill)) {
          intersectionSize++;
        }
      });
      
      const unionSize = taskSkillSet.size + callerSkillSet.size - intersectionSize;
      const skillCompatibility = unionSize > 0 ? intersectionSize / unionSize : 0;
      
      // Calculate experience compatibility
      // Map experience levels to numeric values for comparison
      const experienceMap = {
        'Beginner': 0,
        'Intermediate': 0.5,
        'Advanced': 1
      };
      
      const callerExperienceValue = experienceMap[callerExperienceLevel] || 0.5;
      
      // Check if task is beginner friendly
      const isBeginnerFriendly = taskData.isBeginnerFriendly || false;
      const taskExperienceValue = isBeginnerFriendly ? 0 : 1; // Beginner-friendly = 0, not = 1
      
      // Experience compatibility: closer values = better match
      // We want beginner users (0) to match beginner tasks (0) 
      // and advanced users (1) to match advanced tasks (1)
      const experienceDiff = Math.abs(callerExperienceValue - taskExperienceValue);
      const experienceCompatibility = 1 - Math.min(experienceDiff, 1); // Clamp to [0,1]
      
      // Calculate category compatibility
      // Simple approach: if any caller skill matches task category or tags
      let categoryCompatibility = 0;
      const callerSkillSetLower = new Set(callerSkills.map(s => s.toLowerCase()));
      
      taskSkillSet.forEach(skill => {
        if (callerSkillSetLower.has(skill.toLowerCase())) {
          categoryCompatibility = 1; // Found at least one match
        }
      });
      
      // Calculate beginner priority bonus
      // Less experienced users get higher priority
      const experienceValues = { 'Beginner': 0, 'Intermediate': 0.5, 'Advanced': 1 };
      const callerExperiencePriority = 1 - (experienceValues[callerExperienceLevel] || 0.5);
      // Beginner: 1.0, Intermediate: 0.5, Advanced: 0.0
      
      // Calculate weighted score
      const score = (
        (skillCompatibility * 0.4) +
        (experienceCompatibility * 0.3) +
        (categoryCompatibility * 0.2) +
        (callerExperiencePriority * 0.1)
      );
      
      matchesWithScores.push({
        taskId: taskDoc.id,
        score: parseFloat(score.toFixed(4)), // Limit to 4 decimal places
        task: {
          id: taskDoc.id,
          ...taskData
        },
        matchBreakdown: {
          skillCompatibility: parseFloat(skillCompatibility.toFixed(4)),
          experienceCompatibility: parseFloat(experienceCompatibility.toFixed(4)),
          categoryCompatibility: parseFloat(categoryCompatibility.toFixed(4)),
          beginnerPriority: parseFloat(callerExperiencePriority.toFixed(4))
        }
      });
    });

    // Sort by score descending (highest match first)
    matchesWithScores.sort((a, b) => b.score - a.score);

    // Apply limit
    const limitedMatches = matchesWithScores.slice(0, limit);
    
    // Determine if there are more results for pagination
    const hasMore = matchesWithScores.length > limit;
    const lastReturnedTaskId = limitedMatches.length > 0 
      ? limitedMatches[limitedMatches.length - 1].taskId 
      : null;

    return {
      matches: limitedMatches,
      lastTaskId: lastReturnedTaskId,
      hasMore: hasMore
    };

  } catch (error) {
    console.error('Error in smartMatchTasks:', error);
    if (error.code === 'unauthenticated' || error.code === 'not-found' || error.code === 'invalid-argument') {
      throw error;
    }
    throw new httpsError.HttpsError('internal', 'Unable to perform smart matching', error);
  }
});

// Callable function to send a notification directly
exports.sendNotification = onCall(async (request) => {
  // Authenticate the request
  if (!request.auth) {
    throw new httpsError.HttpsError('unauthenticated', 'User must be authenticated to send notifications');
  }

  const senderUid = request.auth.uid;

  // Validate required fields
  const { recipientId, type, title, body, relatedId, relatedType } = request.data;

  if (!recipientId || !type || !title || !body) {
    throw new httpsError.HttpsError('invalid-argument', 'Missing required fields: recipientId, type, title, body');
  }

  try {
    // Create notification document
    const notificationRef = await db.collection('notifications').add({
      recipientId: recipientId,
      senderId: senderUid,
      type: type,
      title: title,
      body: body,
      relatedId: relatedId || null,
      relatedType: relatedType || null,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      notificationId: notificationRef.id
    };
  } catch (error) {
    console.error('Error sending notification:', error);
    throw new httpsError.HttpsError('internal', 'Unable to send notification', error);
  }
});

// Trigger: Send notification when a task is assigned to a seller
exports.onTaskAssigned = onDocumentCreated("/tasks/{taskId}", async (event) => {
  const taskData = event.data.data();

  // Only trigger when task is assigned (status changes to in_progress and sellerId is set)
  if (taskData.status === 'in_progress' && taskData.sellerId && taskData.buyerId) {
    try {
      // Get buyer info for notification
      const buyerDoc = await db.collection('users').doc(taskData.buyerId).get();
      const buyerName = buyerDoc.exists ? buyerDoc.data().name : 'Someone';

      // Get seller info for notification
      const sellerDoc = await db.collection('users').doc(taskData.sellerId).get();
      const sellerName = sellerDoc.exists ? sellerDoc.data().name : 'Someone';

      // Notify seller that their task was accepted
      await db.collection('notifications').add({
        recipientId: taskData.sellerId,
        senderId: taskData.buyerId,
        type: 'task_assigned',
        title: 'Task Accepted!',
        body: `${buyerName} has accepted your offer for "${taskData.title}"`,
        relatedId: taskData.id,
        relatedType: 'task',
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });

      // Notify buyer that seller started working
      await db.collection('notifications').add({
        recipientId: taskData.buyerId,
        senderId: taskData.sellerId,
        type: 'task_started',
        title: 'Work Started',
        body: `${sellerName} has started working on your task "${taskData.title}"`,
        relatedId: taskData.id,
        relatedType: 'task',
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('Error in onTaskAssigned trigger:', error);
    }
  }
  return null;
});

// Trigger: Send notification when an order is completed
exports.onOrderCompleted = onDocumentUpdated("/orders/{orderId}", async (event) => {
  const beforeData = event.data.before.exists ? event.data.before.data() : null;
  const afterData = event.data.after.data();

  // Only trigger when order status changes to Completed
  if (beforeData && beforeData.status !== 'Completed' && afterData.status === 'Completed') {
    try {
      // Get buyer and seller info
      const buyerDoc = await db.collection('users').doc(afterData.buyerId).get();
      const sellerDoc = await db.collection('users').doc(afterData.sellerId).get();

      const buyerName = buyerDoc.exists ? buyerDoc.data().name : 'Someone';
      const sellerName = sellerDoc.exists ? sellerDoc.data().name : 'Someone';

      // Notify seller that order is completed
      await db.collection('notifications').add({
        recipientId: afterData.sellerId,
        senderId: afterData.buyerId,
        type: 'order_completed',
        title: 'Order Completed!',
        body: `${buyerName} marked your order for "${afterData.title}" as completed`,
        relatedId: afterData.id,
        relatedType: 'order',
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });

      // Notify buyer that order is completed
      await db.collection('notifications').add({
        recipientId: afterData.buyerId,
        senderId: afterData.sellerId,
        type: 'order_completed_buyer',
        title: 'Order Completed!',
        body: `Your order for "${afterData.title}" has been marked as completed by ${sellerName}`,
        relatedId: afterData.id,
        relatedType: 'order',
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('Error in onOrderCompleted trigger:', error);
    }
  }
  return null;
});

// Trigger: Send notification when a new message is received in a chat
exports.onNewMessage = onDocumentCreated("/chats/{chatId}/messages/{messageId}", async (event) => {
  const messageData = event.data.data();

  try {
    // Get chat info to determine participants
    const chatDoc = await db.collection('chats').doc(event.params.chatId).get();
    if (!chatDoc.exists) return null;

    const chatData = chatDoc.data();
    const participants = chatData.participants || [];

    // Get sender info
    const senderDoc = await db.collection('users').doc(messageData.senderId).get();
    if (!senderDoc.exists) return null;

    const senderName = senderDoc.data().name || 'Someone';

    // Send notification to all participants except the sender
    for (const participantId of participants) {
      if (participantId !== messageData.senderId) {
        await db.collection('notifications').add({
          recipientId: participantId,
          senderId: messageData.senderId,
          type: 'new_message',
          title: 'New Message',
          body: `${senderName}: ${messageData.content.substring(0, 50)}${messageData.content.length > 50 ? '...' : ''}`,
          relatedId: chatData.taskId || null,
          relatedType: chatData.taskId ? 'task' : null,
          isRead: false,
          createdAt: FieldValue.serverTimestamp(),
        });
      }
    }
  } catch (error) {
    console.error('Error in onNewMessage trigger:', error);
  }
  return null;
});

// Trigger: Send notification when a user is reported
exports.onUserReported = onDocumentCreated("/reports/{reportId}", async (event) => {
  const reportData = event.data.data();

  try {
    // Get reported user info
    const reportedUserDoc = await db.collection('users').doc(reportData.reportedUserId).get();
    if (!reportedUserDoc.exists) return null;

    // Get reporter info (optional, for context)
    const reporterDoc = await db.collection('users').doc(reportData.reporterId).get();
    const reporterName = reporterDoc.exists ? reporterDoc.data().name : 'Someone';

    // Notify the reported user (anonymously for privacy)
    await db.collection('notifications').add({
      recipientId: reportData.reportedUserId,
      senderId: null, // Anonymous notification
      type: 'user_reported',
      title: 'Report Received',
      body: `A report has been filed against your account. Our team is reviewing it.`,
      relatedId: reportData.id,
      relatedType: 'report',
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error('Error in onUserReported trigger:', error);
  }
  return null;
});

// Trigger: Send notification when a user's verification status changes
exports.onVerificationStatusChanged = onDocumentUpdated("/users/{userId}", async (event) => {
  const beforeData = event.data.before.exists ? event.data.before.data() : null;
  const afterData = event.data.after.data();

  // Only trigger when verification status changes
  if (beforeData && afterData &&
      ((beforeData.isVerified !== afterData.isVerified) ||
       (beforeData.verificationStatus !== afterData.verificationStatus))) {
    try {
      const status = afterData.isVerified ? 'verified' : 'verification_failed';
      const title = afterData.isVerified ? 'Account Verified!' : 'Verification Update';
      const body = afterData.isVerified
        ? 'Your account has been successfully verified!'
        : 'There was an issue with your verification. Please try again or contact support.';

      await db.collection('notifications').add({
        recipientId: afterData.userId,
        senderId: null, // System notification
        type: 'verification_status',
        title: title,
        body: body,
        relatedId: null,
        relatedType: null,
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('Error in onVerificationStatusChanged trigger:', error);
    }
  }
  return null;
});

// Block a user (admin/moderator only)
exports.blockUser = onCall(async (request) => {
  // Authenticate the request
  if (!request.auth) {
    throw new httpsError.HttpsError('unauthenticated', 'User must be authenticated to perform this action');
  }

  const callerUid = request.auth.uid;
  const targetUid = request.data.uid;

  // Validate input
  if (!targetUid) {
    throw new httpsError.HttpsError('invalid-argument', 'User ID (uid) is required');
  }

  try {
    // Get caller's user document to check permissions
    const callerDoc = await db.collection('users').doc(callerUid).get();
    if (!callerDoc.exists) {
      throw new httpsError.HttpsError('not-found', 'Caller user not found');
    }

    const callerData = callerDoc.data();

    // Check if caller is admin or moderator
    if (!callerData.isAdmin && !callerData.isModerator) {
      throw new httpsError.HttpsError('permission-denied', 'Only administrators and moderators can block users');
    }

    // Get target user document
    const targetDoc = await db.collection('users').doc(targetUid).get();
    if (!targetDoc.exists) {
      throw new httpsError.HttpsError('not-found', 'Target user not found');
    }

    // Prevent admins/moderators from blocking other admins/moderators (optional security measure)
    const targetData = targetDoc.data();
    if (targetData.isAdmin || targetData.isModerator) {
      throw new httpsError.HttpsError('permission-denied', 'Cannot block administrators or moderators');
    }

    // Block the user
    await db.collection('users').doc(targetUid).update({
      isBlocked: true,
      blockedAt: FieldValue.serverTimestamp(),
    });

    // Notify the blocked user (optional - for transparency)
    try {
      await db.collection('notifications').add({
        recipientId: targetUid,
        senderId: null, // System notification
        type: 'user_blocked',
        title: 'Account Blocked',
        body: 'Your account has been blocked by an administrator. Please contact support if you believe this is in error.',
        relatedId: null,
        relatedType: null,
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    } catch (notificationError) {
      // Don't fail the blocking operation if notification fails
      console.warn('Failed to send block notification:', notificationError);
    }

    return {
      success: true,
      uid: targetUid,
      blockedAt: FieldValue.serverTimestamp(),
    };
  } catch (error) {
    console.error('Error in blockUser:', error);
    if (error.code === 'unauthenticated' || error.code === 'not-found' || error.code === 'invalid-argument' || error.code === 'permission-denied') {
      throw error;
    }
    throw new httpsError.HttpsError('internal', 'Unable to block user', error);
  }
});

// Unblock a user (admin/moderator only)
exports.unblockUser = onCall(async (request) => {
  // Authenticate the request
  if (!request.auth) {
    throw new httpsError.HttpsError('unauthenticated', 'User must be authenticated to perform this action');
  }

  const callerUid = request.auth.uid;
  const targetUid = request.data.uid;

  // Validate input
  if (!targetUid) {
    throw new httpsError.HttpsError('invalid-argument', 'User ID (uid) is required');
  }

  try {
    // Get caller's user document to check permissions
    const callerDoc = await db.collection('users').doc(callerUid).get();
    if (!callerDoc.exists) {
      throw new httpsError.HttpsError('not-found', 'Caller user not found');
    }

    const callerData = callerDoc.data();

    // Check if caller is admin or moderator
    if (!callerData.isAdmin && !callerData.isModerator) {
      throw new httpsError.HttpsError('permission-denied', 'Only administrators and moderators can unblock users');
    }

    // Get target user document
    const targetDoc = await db.collection('users').doc(targetUid).get();
    if (!targetDoc.exists) {
      throw new httpsError.HttpsError('not-found', 'Target user not found');
    }

    // Unblock the user
    await db.collection('users').doc(targetUid).update({
      isBlocked: false,
      unblockedAt: FieldValue.serverTimestamp(),
      // Clear the blockedAt timestamp
      blockedAt: FieldValue.delete(),
    });

    // Notify the unblocked user (optional - for transparency)
    try {
      await db.collection('notifications').add({
        recipientId: targetUid,
        senderId: null, // System notification
        type: 'user_unblocked',
        title: 'Account Unblocked',
        body: 'Your account has been unblocked and is now accessible again.',
        relatedId: null,
        relatedType: null,
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    } catch (notificationError) {
      // Don't fail the unblocking operation if notification fails
      console.warn('Failed to send unblock notification:', notificationError);
    }

    return {
      success: true,
      uid: targetUid,
      unblockedAt: FieldValue.serverTimestamp(),
    };
  } catch (error) {
    console.error('Error in unblockUser:', error);
    if (error.code === 'unauthenticated' || error.code === 'not-found' || error.code === 'invalid-argument' || error.code === 'permission-denied') {
      throw error;
    }
    throw new httpsError.HttpsError('internal', 'Unable to unblock user', error);
  }
});

// Create or reset QA/test bot account for testing infrastructure
exports.createOrResetTestBot = onCall(async (request) => {
  // Authenticate the request - only admins can manage test bot
  if (!request.auth) {
    throw new httpsError.HttpsError('unauthenticated', 'User must be authenticated to manage test bot account');
  }

  const callerUid = request.auth.uid;

  try {
    // Get caller's user document to check permissions
    const callerDoc = await db.collection('users').doc(callerUid).get();
    if (!callerDoc.exists) {
      throw new httpsError.HttpsError('not-found', 'Caller user not found');
    }

    const callerData = callerDoc.data();

    // Check if caller is admin
    if (!callerData.isAdmin) {
      throw new httpsError.HttpsError('permission-denied', 'Only administrators can manage the test bot account');
    }

    // Define test bot account properties
    const testBotUid = 'test-bot-account'; // Fixed UID for consistency
    const testBotEmail = 'testbot@arah.app';
    const testBotUsername = 'testbot';
    const testBotName = 'ARAH Test Bot';

    // Check if test bot account already exists in Firirestore
    const testBotDoc = await db.collection('users').doc(testBotUid).get();

    if (testBotDoc.exists) {
      // Update existing test bot account to known state
      await db.collection('users').doc(testBotUid).update({
        name: testBotName,
        email: testBotEmail,
        username: testBotUsername,
        role: 'Both', // Can act as both buyer and seller for comprehensive testing
        currentMode: 'Buyer',
        bio: 'This is a test bot account for QA and automated testing purposes.',
        experienceLevel: 'Intermediate',
        skills: ['testing', 'qa', 'automation'],
        photoUrl: '',
        githubUrl: '',
        linkedinUrl: '',
        isProfilePublic: true,
        isBlocked: false,
        isAdmin: false, // Test bot is not an admin by default
        isModerator: false,
        isVerified: true, // Pre-verified to avoid email verification hurdles in tests
        verificationDate: FieldValue.serverTimestamp(),
        // Note: We intentionally do not modify password or auth-related fields here
        // as those are managed in Firebase Auth, not Firestore
        updatedAt: FieldValue.serverTimestamp()
      });
    } else {
      // Create new test bot account
      await db.collection('users').doc(testBotUid).set({
        id: testBotUid,
        name: testBotName,
        email: testBotEmail,
        username: testBotUsername,
        role: 'Both',
        currentMode: 'Buyer',
        bio: 'This is a test bot account for QA and automated testing purposes.',
        experienceLevel: 'Intermediate',
        skills: ['testing', 'qa', 'automation'],
        photoUrl: '',
        githubUrl: '',
        linkedinUrl: '',
        isProfilePublic: true,
        isBlocked: false,
        isAdmin: false,
        isModerator: false,
        isVerified: true,
        verificationDate: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
      });
    }

    // Optionally, create some test data associated with the test bot
    // For example, create a sample task or chat history
    // This is commented out for safety - uncomment if needed for specific test scenarios
    /*
    try {
      // Create a sample task for the test bot
      const sampleTaskRef = await db.collection('tasks').add({
        title: 'Sample Test Task',
        description: 'This is a sample task created for the test bot account.',
        category: 'Testing',
        price: '���₹0',
        buyerId: testBotUid,
        buyerName: testBotName,
        status: 'open',
        isBeginnerFriendly: true,
        tags: ['testing', 'sample'],
        createdAt: FieldValue.serverTimestamp(),
        postedTime: 'Just now'
      });
    } catch (taskError) {
      console.warn('Failed to create sample task for test bot:', taskError);
      // Don't fail the entire operation if test data creation fails
    }
    */

    return {
      success: true,
      uid: testBotUid,
      email: testBotEmail,
      username: testBotUsername,
      message: 'Test bot account created or reset successfully'
    };
  } catch (error) {
    console.error('Error in createOrResetTestBot:', error);
    if (error.code === 'unauthenticated' || error.code === 'not-found' || error.code === 'invalid-argument' || error.code === 'permission-denied') {
      throw error;
    }
    throw new httpsError.HttpsError('internal', 'Unable to create or reset test bot account', error);
  }
});
