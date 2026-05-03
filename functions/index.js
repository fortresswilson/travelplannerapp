const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

exports.optimizeItinerary = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in.');
  }

  const tripId = data.tripId;
  if (!tripId) {
    throw new functions.https.HttpsError('invalid-argument', 'tripId is required.');
  }

  const tripSnap = await db.doc('trips/' + tripId).get();
  const activitiesSnap = await db.collection('trips/' + tripId + '/activities').get();
  const votesSnap = await db.collection('trips/' + tripId + '/votes').get();

  if (!tripSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Trip not found.');
  }

  const trip = tripSnap.data();
  const budgetRemaining = (trip.budgetTotal || 0) - (trip.budgetSpent || 0);

  const voteCounts = {};
  votesSnap.docs.forEach(function(voteDoc) {
    const votes = voteDoc.data().votes || {};
    let yes = 0, no = 0, maybe = 0;
    Object.values(votes).forEach(function(v) {
      if (v === 'yes') yes++;
      else if (v === 'no') no++;
      else maybe++;
    });
    voteCounts[voteDoc.id] = { yes: yes, no: no, maybe: maybe };
  });

  const activities = activitiesSnap.docs.map(function(doc) {
    const d = doc.data();
    d.id = doc.id;
    return d;
  });

  const maxDist = Math.max.apply(null, activities.map(function(a) { return a.distanceKm || 0; }).concat([1]));

  const results = activities.map(function(act) {
    const votes = voteCounts[act.id] || { yes: 0, no: 0, maybe: 0 };
    const totalVoters = votes.yes + votes.no + votes.maybe || 1;
    const netVote = (votes.yes + votes.maybe * 0.5 - votes.no) / totalVoters;
    const voteScore = Math.round(((netVote + 1) / 2) * 35);
    const distScore = Math.round((1 - (act.distanceKm || 0) / maxDist) * 25);
    const budgetScore = budgetRemaining > 0 ? Math.round((1 - Math.min((act.cost || 0) / budgetRemaining, 1)) * 25) : 0;
    const popScore = Math.min(act.popularityScore || 10, 15);
    const totalScore = Math.min(voteScore + distScore + budgetScore + popScore, 100);
    const reason = 'Votes ' + voteScore + '/35 - Distance ' + distScore + '/25 - Budget ' + budgetScore + '/25 - Popularity ' + popScore + '/15';
    return { activityId: act.id, score: totalScore, reason: reason };
  });

  results.sort(function(a, b) { return b.score - a.score; });

  const batch = db.batch();
  results.forEach(function(result, index) {
    const ref = db.doc('trips/' + tripId + '/activities/' + result.activityId);
    batch.update(ref, { score: result.score, scoreReason: result.reason, order: index });
  });
  await batch.commit();

  return { activities: results };
});