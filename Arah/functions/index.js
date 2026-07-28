const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall } = require('firebase-functions/v2/https');
const { httpsError } = require('firebase-functions/v2/https');

// Initialize Firebase Admin SDK
initializeApp();

const db = getFirestore();
const auth = getAuth();

// Function to clean up old notifications (older than 30 days)
exports.cleanupOldNotifications = onSchedule(
  {
    schedule: '0 2 * * *', // Every day at 2 AM
    timeZone: 'America/New_York',
  },
  async (event) => {
    try {
      const cutoff = Date.now() - 30 * 24 * 60 * 60 * 1000; // 30 days ago
      const cutoffTimestamp = Timestamp.fromMillis(cutoff);

      const notificationsRef = db.collection('notifications');
      const snapshot = await notificationsRef
        .where('createdAt', '<', cutoffTimestamp)
        .limit(500) // Process in batches to avoid timeout
        .get();

      if (snapshot.empty) {
        console.log('No old notifications to delete.');
        return null;
      }

      const batch = db.batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log(`Deleted ${snapshot.size} old notifications.`);

      // If there are more than 500, the function will be triggered again by the scheduler
      // and continue until all are deleted. Alternatively, we can set up a queue.
      return null;
    } catch (error) {
      console.error('Error in cleanupOldNotifications:', error);
      throw error;
    }
  }
);

// Function to repair user ratings (recalculate average and count)
exports.repairUserRatings = onSchedule(
  {
    schedule: '0 3 * * 0', // Every Sunday at 3 AM
    timeZone: 'America/New_York',
  },
  async (event) => {
    try {
      const usersRef = db.collection('users');
      const snapshot = await usersRef.get();

      const updatePromises = [];
      snapshot.forEach(async (userDoc) => {
        const userId = userDoc.id;
        const ratingsRef = db.collection('users').doc(userId).collection('ratings');
        const ratingsSnapshot = await ratingsRef.get();

        if (!ratingsSnapshot.empty) {
          let total = 0;
          let count = 0;
          ratingsSnapshot.forEach((ratingDoc) => {
            const data = ratingDoc.data();
            if (data.rating !== undefined && data.rating !== null) {
              total += data.rating;
              count++;
            }
          });

          if (count > 0) {
            const average = total / count;
            updatePromises.push(
              userDoc.ref.update({
                avgRating: average,
                ratingCount: count,
              })
            );
          } else {
            // If no ratings, set average to 0 and count to 0
            updatePromises.push(
              userDoc.ref.update({
                avgRating: 0,
                ratingCount: 0,
              })
            );
          }
        } else {
          // If no ratings subcollection, set average to 0 and count to 0
          updatePromises.push(
            userDoc.ref.update({
              avgRating: 0,
              ratingCount: 0,
            })
          );
        }
      });

      await Promise.all(updatePromises);
      console.log(`Updated ratings for ${snapshot.size} users.`);
      return null;
    } catch (error) {
      console.error('Error in repairUserRatings:', error);
      throw error;
    }
  }
);

// Callable function to validate password strength
exports.validatePasswordStrength = onCall(async (request) => {
  // Authenticate the request (optional for this function, but good practice)
  // if (!request.auth) {
  //   throw new httpsError.HttpsError('unauthenticated', 'User must be authenticated');
  // }

  const password = request.data.password;
  if (!password || typeof password !== 'string') {
    throw new httpsError.HttpsError('invalid-argument', 'Password must be a non-empty string');
  }

  // Password strength validation rules
  const minLength = 8;
  const hasUpperCase = /[A-Z]/.test(password);
  const hasLowerCase = /[a-z]/.test(password);
  const hasNumbers = /[0-9]/.test(password);
  const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(password);
  const isLongEnough = password.length >= minLength;

  let score = 0;
  if (isLongEnough) score++;
  if (hasUpperCase) score++;
  if (hasLowerCase) score++;
  if (hasNumbers) score++;
  if (hasSpecialChar) score++;

  let strength = 'very weak';
  if (score >= 4) strength = 'strong';
  else if (score >= 3) strength = 'medium';
  else if (score >= 2) strength = 'weak';

  return {
    valid: score >= 4, // Consider valid if strong (4+ points)
    score,
    strength,
    length: password.length,
    feedback: {
      length: isLongEnough ? null : `Password should be at least ${minLength} characters long`,
      uppercase: hasUpperCase ? null : 'Password should contain at least one uppercase letter',
      lowercase: hasLowerCase ? null : 'Password should contain at least one lowercase letter',
      numbers: hasNumbers ? null : 'Password should contain at least one number',
      specialChars: hasSpecialChar ? null : 'Password should contain at least one special character (!@#$%^&*(),.?":{}|<>)',
    }
  };
});

// Callable function to send email verification
exports.sendEmailVerification = onCall(async (request) => {
  if (!request.auth) {
    throw new httpsError.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = request.auth.uid;
  try {
    // Get the user record
    const userRecord = await auth.getUser(uid);
    if (userRecord.emailVerified) {
      return { alreadyVerified: true, email: userRecord.email };
    }

    // Generate email verification link
    const link = await auth.generateEmailVerificationLink(userRecord.email);

    // TODO: Send email via email service (SendGrid, Mailgun, etc.) or use Firebase Action Code Settings
    // For now, we return the link to the client to handle sending via their preferred email service
    return { email: userRecord.email, verificationLink: link };
  } catch (error) {
    console.error('Error generating email verification link:', error);
    throw new httpsError.HttpsError('internal', 'Unable to generate email verification link', error);
  }
});

// Callable function to change password securely with session revocation
exports.changePasswordSecure = onCall(async (request) => {
  if (!request.auth) {
    throw new httpsError.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = request.auth.uid;
  const newPassword = request.data.newPassword;

  if (!newPassword || typeof newPassword !== 'string') {
    throw new httpsError.HttpsError('invalid-argument', 'New password must be a non-empty string');
  }

  // Optional: Validate password strength here or rely on client-side validation
  // For now, we'll just update the password and revoke sessions

  try {
    // Get the user to verify they exist
    const userRecord = await auth.getUser(uid);

    // Update the password
    await auth.updateUser(uid, {
      password: newPassword
    });

    // Revoke refresh tokens for this user to invalidate existing sessions
    await auth.revokeRefreshTokens(uid);

    console.log(`Password changed and sessions revoked for user ${uid}`);
    return { success: true, uid };
  } catch (error) {
    console.error('Error in changePasswordSecure:', error);
    throw new httpsError.HttpsError('internal', 'Unable to change password', error);
  }
});

// Callable function to revoke refresh tokens (sessions) for a user
exports.revokeRefreshTokens = onCall(async (request) => {
  if (!request.auth) {
    throw new httpsError.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = request.auth.uid;
  // Optional: allow admin to specify another uid? For now, only self.
  // const targetUid = request.data.uid || uid;

  try {
    // Revoke refresh tokens for the specified user
    await auth.revokeRefreshTokens(uid);
    console.log(`Revoked refresh tokens for user ${uid}`);
    return { success: true, uid };
  } catch (error) {
    console.error('Error revoking refresh tokens:', error);
    throw new httpsError.HttpsError('internal', 'Unable to revoke sessions', error);
  }
});