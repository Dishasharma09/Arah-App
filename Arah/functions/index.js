const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');

// Initialize Firebase Admin SDK
initializeApp();

const db = getFirestore();

// Function to clean up old notifications (older than 30 days)
exports.cleanupOldNotifications = onSchedule(
  {
    schedule: '0 2 * * *', // Every day at 2 AM
    timeZone: 'America/New_York', // Adjust timezone as needed
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
          }
        } else {
          // If no ratings, set average to 0 and count to 0
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