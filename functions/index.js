const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

exports.optimizeItinerary = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in.');
  }
  const { tripId } = data;
  if (!tripId) {
    throw new functions.https.HttpsError('invalid-argument', 'tripId is required.');
  }
  const [tripSnap, activitiesSnap, votesSnap] = await Promise.all([
    db.doc(`trips/${tripId}`).get(),
    db.collection(`trips/${tripId}/activities`).get(),
    db.collection(`trips/${tripId}/votes`).get(),
  ]);
  if (!tripSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Trip not found.');
  }
  const trip = tripSnap.data();
  const budgetRemaining = (trip.budgetTotal || 0) - (trip.budgetSpent || 0);
  const voteCounts = {};
  for (const voteDoc of votesSnap.docs) {
    const votes = voteDoc.data()    const votes = voteDoc.da0,    const votes = voteDoc.data()    const voct.values(votes)) {
      if (v === '✅') yes+      if (v === '� ===      if (v === '✅') yes+ (v       if (v === '✅') yes+      if (v === '� ===      if (v === '✅') y;
                       =                        =                        =                        =       = Math                       = => a.distanceKm || 0), 1);
  const results = activities.map(act => {
    const votes = voteCounts[act.id] || { yes: 0, no: 0, maybe: 0 };
    const totalVoters = votes.yes + votes.no + votes.maybe || 1;
    const netVote = (votes.yes + votes.maybe * 0.5 - votes.no) / totalVoters;
    const voteScore = Math.round(((netVote + 1) / 2) * 35);
    const distScore = Math.round((1 - (act.distanceKm || 0) / maxDist) * 25);
    const budgetScore = budgetRemaining > 0 ? Math.round((1 - Math.min(act.cost / budgetRemaining, 1)) * 25) : 0;
    const popScore = Math.min(act.popularityScore || 10, 15);
    const    const    const    const    const    const    const    const    const    const    const    const    const    const    costa    const    const    const    const    const    const    const    const    const    const    const    const    const    const    costa    const    const 
                                                                                                                                                                    {r                                        f,                                                                 });
                                                               p((r, i) => ({ ...r, order: i })) };
});
