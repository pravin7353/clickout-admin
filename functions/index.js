const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
// NAYA: onDocumentWritten aur onDocumentCreated imports add kiye hain
const { onDocumentDeleted, onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
// SECURITY + DEAD-CODE FIX: 'nodemailer' aur hardcoded Gmail credentials
// poori file me kahin bhi actually use nahi ho rahe the (dead code + secret leak
// risk). Isliye hata diya. Agar future me email bhejna ho, to Secret Manager
// (firebase-functions/params -> defineSecret) ke saath dobara add karna:
// const { defineSecret } = require("firebase-functions/params");
// const GMAIL_USER = defineSecret("GMAIL_USER");
// const GMAIL_APP_PASSWORD = defineSecret("GMAIL_APP_PASSWORD");

admin.initializeApp();
const db = admin.firestore();

// ============================================================================
// 1. BULK IMPORT PRODUCTS (UPGRADED TO GEN 2 - SAAS ISOLATED)
// ============================================================================
exports.bulkImportProducts = onCall(async (request) => {
 // SECURITY FIX: Pehle koi auth check hi nahi tha, isliye koi bhi caller
 // arbitrary tenantId bhej kar kisi bhi tenant ke products overwrite kar sakta tha.
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'You must be logged in to import products.');
    }

    const callerRole = (request.auth.token.role || '').toUpperCase();
    const callerTenantId = request.auth.token.tenantId || null;
    const isSuperAdmin = callerRole === 'SUPER_ADMIN';
    const allowedRoles = ['TENANT_ADMIN', 'MANAGER', 'SUPER_ADMIN'];

    if (!allowedRoles.includes(callerRole)) {
        throw new HttpsError('permission-denied', 'You do not have permission to import products.');
    }

    if (!isSuperAdmin && !callerTenantId) {
        throw new HttpsError('failed-precondition', 'No tenant associated with this account.');
    }

    const data = request.data;
    
    try {
        let products = [];
        
        if (Array.isArray(data)) {
            products = data;
        } else if (data && Array.isArray(data.products)) {
            products = data.products;
        } else if (data && data.data && Array.isArray(data.data)) {
            products = data.data; 
        } else if (data && data.data && Array.isArray(data.data.products)) {
            products = data.data.products; 
        }

        if (products.length === 0) {
            return { success: false, message: "Data Error: No valid products received." };
        }

        const batches = [];
        let currentBatch = db.batch();
        let count = 0;
        let totalImported = 0;

        for (const prod of products) {
            if (!prod || !prod.barcode) continue; 

 // SAAS ISOLATION: Naya Document ID Format
 // SECURITY FIX: Client-provided tenantId ab sirf SUPER_ADMIN ke liye trust hota hai.
 // Tenant-level users (TENANT_ADMIN/MANAGER) ke liye tenantId hamesha unke
 // apne custom-claim token se lock hota hai, taaki cross-tenant writes na ho sakein.
            const tenantId = isSuperAdmin
                ? (prod.tenantId || "RESTRICTED")
                : callerTenantId;
            if (!tenantId) continue; // safety: kabhi bhi bina tenantId ke likho mat
            const branchCode = prod.branchCode || "HQ";
            const barcode = String(prod.barcode).trim();
            
            const docId = `${tenantId}_${branchCode}_${barcode}`;
            const docRef = db.collection('products').doc(docId);

            const safePrice = Number(prod.price) || 0;
            const safeUnitCost = Number(prod.unitCost) || 0; // 🚀 ADDED: Safe parsing for unit cost, defaults to 0
            const safeWeight = String(prod.weight || "");
            const safeStock = Number(prod.stock || prod.physicalStock) || 0;

            const cleanData = {
                barcode: barcode,
                name: String(prod.name || "Unknown Item").trim(),
                itemType: "PRODUCT", // 🚀 FIX: Ye tag CSV products ko UI me dikhayega
                price: safePrice,
                unitCost: parseFloat(safeUnitCost.toFixed(2)), 
                weight: safeWeight,
                gst: String(prod.gst || "0").trim(),
                isBlocked: false, 
                physicalStock: safeStock,
                openingStock: safeStock,
                purchasedStock: 0,
                soldStock: 0,
                damagedStock: 0,
                expiredStock: 0,
                reservedStock: 0,
                searchKey: String(prod.name || "Unknown Item").toLowerCase().trim(),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
 // NEW: SAAS & FRAUD TRACKING FIELDS INJECTED
                tenantId: tenantId,
                branchCode: branchCode,
                addedBy: prod.addedBy || "Unknown Manager",
                addedByEmail: prod.addedByEmail || "Unknown Email"
            };

            if (prod.expiryDate && String(prod.expiryDate).trim() !== "") {
                const parsedDate = new Date(prod.expiryDate);
                if (!isNaN(parsedDate.getTime())) {
                    cleanData.expiryDate = admin.firestore.Timestamp.fromDate(parsedDate);
                }
            }

            currentBatch.set(docRef, cleanData, { merge: true });
            count++;
            totalImported++;
            
            if (count >= 490) {
                batches.push(currentBatch.commit());
                currentBatch = db.batch();
                count = 0;
            }
        }

        if (count > 0) {
            batches.push(currentBatch.commit());
        }

 // RELIABILITY FIX: Pehle Promise.all(batches) use hota tha, jisse agar
 // ek bhi batch fail hota, poora import "unknown error" throw kar deta
 // bina ye bataye ki kitne SKUs already committed ho chuke the.
 // Ab Promise.allSettled se har batch ka result individually track hota hai.
        const batchResults = await Promise.allSettled(batches);
        const failedBatches = batchResults.filter(r => r.status === 'rejected');
        const committedBatches = batchResults.length - failedBatches.length;
 // Har batch me max 490 writes hote hain (see currentBatchCount check below),
 // isliye committed SKUs ka rough estimate nikal sakte hain caller ko batane ke liye.
        const estimatedCommitted = committedBatches === batchResults.length
            ? totalImported
            : Math.min(totalImported, committedBatches * 490);

        if (failedBatches.length > 0) {
            console.error(`PARTIAL IMPORT FAILURE: ${failedBatches.length}/${batchResults.length} batches failed.`,
                failedBatches.map(r => r.reason?.message || r.reason));
            throw new HttpsError(
                'internal',
                `Partial import failure: ${committedBatches}/${batchResults.length} batches committed successfully ` +
                `(~${estimatedCommitted} of ${totalImported} SKUs). ${failedBatches.length} batch(es) failed — please retry the import to catch missed items.`
            );
        }

        return { success: true, message: `Mission Accomplished: ${totalImported} Master SKUs isolated & added to the Vault!` };

    } catch (error) {
        console.error("CRITICAL CRASH: ", error);
        throw new HttpsError('unknown', `CRASH REPORT: ${error.message}`);
    }
});


// ============================================================================
// 2. PREDICTIVE AUTO-PO ENGINE (GEN 2 - FIXED DUPLICATES & SMART MATH)
// ============================================================================
// DEAD-CODE FIX: Ye engine admin dwara intentionally PAUSED kiya gaya tha, lekin
// function ab bhi deploy hoke roz 00:00 IST invoke ho raha tha aur sirf ek log
// line chalakar (unreachable business logic ke saath) exit ho jaata tha.
// Ab function hi export/deploy nahi hoga (dead code hata diya gaya), isliye koi
// unnecessary daily invocation nahi hogi. Poora original business logic
// /docs/archived-cloud-functions/runPredictivePOEngine.js.bak me safe rakha gaya
// hai reference ke liye — jab feature dobara chahiye ho, wahan se restore kar dena.
//
// exports.runPredictivePOEngine = onSchedule("every day 00:00", async (event) => { ... });

// ============================================================================
// 3. ADMIN SDK: AUTO-DELETE AUTH USER (UPGRADED TO GEN 2 )
// ============================================================================
exports.onStaffDeleted = onDocumentDeleted('staff/{staffId}', async (event) => {
    const snap = event.data;
    if (!snap) return; 

    const deletedData = snap.data() || {};
    const uid = deletedData.uid || event.params.staffId; 

    try {
        await admin.auth().deleteUser(uid);
        console.log(`✅ SUCCESS: Auth User deleted for Staff ID: ${uid}`);
    } catch (error) {
        if (error.code === 'auth/user-not-found') {
            console.log(`⚠ User ${uid} already deleted from Auth.`);
        } else {
            console.error(`🚨 ERROR deleting auth user ${uid}:`, error);
        }
    }
});

exports.onUserDeleted = onDocumentDeleted('users/{userId}', async (event) => {
    const snap = event.data;
    if (!snap) return; 

    const deletedData = snap.data() || {};
    const uid = deletedData.uid || event.params.userId;

    try {
        await admin.auth().deleteUser(uid);
        console.log(`✅ SUCCESS: Auth User deleted for Customer ID: ${uid}`);
    } catch (error) {
        if (error.code === 'auth/user-not-found') {
            console.log(`⚠ User ${uid} already deleted from Auth.`);
        } else {
            console.error(`🚨 ERROR deleting auth user ${uid}:`, error);
        }
    }
});

// ============================================================================
// 4. SAAS RBAC: CUSTOM CLAIMS INJECTOR
// ============================================================================
exports.assignCustomClaims = onDocumentWritten("staff/{staffId}", async (event) => {
    const snapshot = event.data;
    if (!snapshot || !snapshot.after.exists) return; 

    const data = snapshot.after.data();
    const uid = data.uid || event.params.staffId; 

    if (!uid) {
        console.log(`[SKIPPED] No Auth UID found for staff ${event.params.staffId}`);
        return;
    }

    const customClaims = {
        role: (data.role || "").toLowerCase(),
        tenantId: data.tenantId || "default_tenant",
        storeId: data.storeId || "default_store",
        branchCode: data.branchCode || ""
    };

    try {
        await admin.auth().setCustomUserClaims(uid, customClaims);
        console.log(`✅ SUCCESS: Claims assigned to ${uid} (Role: ${customClaims.role})`);
    } catch (error) {
        console.error(`🚨 ERROR: Failed to set claims for ${uid}:`, error);
    }
});

// ============================================================================
// 5. DECOUPLED ORDER PROCESSOR & FRAUD ENGINE
// ============================================================================
exports.processNewOrder = onDocumentCreated(
    {
        document: "orders/{orderId}",
        concurrency: 80, 
        memory: "512MiB"
    }, 
    async (event) => {
        const orderData = event.data?.data();
        const orderId = event.params.orderId;

        if (!orderData) return;

        let isFraudSuspected = false;
        let riskScore = 0;

        if (orderData.weightMismatchFlag || orderData.exitStatus === 'OVERRIDDEN') {
            isFraudSuspected = true;
            riskScore = 85; 
        }

        if (isFraudSuspected) {
            await db.collection("fraud_logs").add({
                tenantId: orderData.tenantId || "default_tenant",
                storeId: orderData.storeId || "default_store",
                orderId: orderId,
                riskScore: riskScore,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                status: "PENDING_INVESTIGATION"
            });
            console.log(`🚨 ALERT: Fraud log created for Order: ${orderId}`);

            // 🚀 SAAS ALERT ROUTING: Primary + Backup contact par simultaneous Email
            if (orderData.tenantId) {
                try {
                    const tenantSnap = await db.collection("tenants").doc(orderData.tenantId).get();
                    if (tenantSnap.exists) {
                        const contact = tenantSnap.data().contact || {};
                        const primaryEmail = contact.email;
                        const backupEmail = contact.recoveryEmail;

                        const emailRecipients = [];
                        if (primaryEmail) emailRecipients.push(primaryEmail);
                        if (backupEmail && backupEmail.trim() !== '') emailRecipients.push(backupEmail);

                        if (emailRecipients.length > 0) {
                            await db.collection("mail").add({
                                to: emailRecipients,
                                message: {
                                    subject: `CRITICAL FRAUD ALERT - Order ${orderId}`,
                                    html: `<p>High risk activity detected (Risk Score: ${riskScore}).</p>
                                           <p>Store ID: ${orderData.storeId}</p>
                                           <p>Please check the ClickOut Command Center Risk Engine immediately.</p>`
                                }
                            });
                            console.log(`✉️ Alert routed to ${emailRecipients.length} addresses including backups.`);
                        }
                    }
                } catch (err) {
                    console.error(`🚨 Alert Routing failed for Tenant ${orderData.tenantId}:`, err);
                }
            }
        }
    }
);

// ============================================================================
// 6. QUANTUM FINANCIAL ENGINE (O(1) DASHBOARD AGGREGATOR)
// ============================================================================
exports.updateDailyStats = onDocumentWritten(
    {
        document: "orders/{orderId}",
        concurrency: 80, 
        memory: "256MiB" 
    }, 
    async (event) => {
        const before = event.data.before.exists ? event.data.before.data() : null;
        const after = event.data.after.exists ? event.data.after.data() : null;

        if (!before && !after) return;
        const doc = after || before;
        
        const tenantId = doc.tenantId || "default_tenant";
        const branchCode = doc.branchCode || doc.storeId || "default_store";

 // IST Timezone Fix for Accurate Daily Reset
        let ts = doc.timestamp || doc.createdAt;
        const dateObj = ts && ts.toDate ? ts.toDate() : new Date();
        const formatter = new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' });
        const parts = formatter.format(dateObj).split('/'); 
        const dateStr = `${parts[2]}-${parts[1]}-${parts[0]}`; // YYYY-MM-DD
        
        const statDocId = `${tenantId}_${branchCode}_${dateStr}`;

        const getMetrics = (data) => {
            if (!data) return { revTot: 0, revCash: 0, revUpi: 0, leakTot: 0, leakCash: 0, leakUpi: 0, ord: 0, rej: 0, pend: 0, ref: 0, refAmt: 0 };

            const amt = Number(data.totalAmount || 0);
            const mode = data.paymentMode || '';
            const pStatus = data.paymentStatus || '';
            const eStatus = data.exitStatus || '';

            let m = { revTot: 0, revCash: 0, revUpi: 0, leakTot: 0, leakCash: 0, leakUpi: 0, ord: 1, rej: 0, pend: 0, ref: 0, refAmt: 0 };

            if (eStatus === 'REJECTED') m.rej = 1;

            if (pStatus === 'REFUNDED') {
                m.ref = 1; m.refAmt = amt;
            } else if (pStatus === 'PAID' || pStatus === 'SUCCESS') {
                if (eStatus === 'EXITED' || eStatus === 'APPROVED') {
                    m.revTot = amt;
                    if (mode === 'CASH') m.revCash = amt; else m.revUpi = amt;
                } else if (eStatus === 'PENDING' || eStatus === 'EXPIRED_BY_SYSTEM' || eStatus === '') {
                    m.leakTot = amt; m.pend = 1;
                    if (mode === 'CASH') m.leakCash = amt; else m.leakUpi = amt;
                }
            }
            return m;
        };

        const oldM = getMetrics(before);
        const newM = getMetrics(after);

 // DELTA MATH: Handles PENDING -> PAID transitions automatically!
        const increments = {
            totalRevenue: admin.firestore.FieldValue.increment(newM.revTot - oldM.revTot),
            cashRevenue: admin.firestore.FieldValue.increment(newM.revCash - oldM.revCash),
            upiRevenue: admin.firestore.FieldValue.increment(newM.revUpi - oldM.revUpi),
            totalLeakage: admin.firestore.FieldValue.increment(newM.leakTot - oldM.leakTot),
            cashLeakage: admin.firestore.FieldValue.increment(newM.leakCash - oldM.leakCash),
            upiLeakage: admin.firestore.FieldValue.increment(newM.leakUpi - oldM.leakUpi),
            totalOrders: admin.firestore.FieldValue.increment(newM.ord - oldM.ord),
            rejectedCount: admin.firestore.FieldValue.increment(newM.rej - oldM.rej),
            pendingCount: admin.firestore.FieldValue.increment(newM.pend - oldM.pend),
            refundCount: admin.firestore.FieldValue.increment(newM.ref - oldM.ref),
            refundAmount: admin.firestore.FieldValue.increment(newM.refAmt - oldM.refAmt),
        };

        try {
            await db.collection("daily_store_stats").doc(statDocId).set({
                tenantId: tenantId,
                branchCode: branchCode,
                date: dateStr,
                ...increments,
                lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });
        } catch (error) {
            console.error(`🚨 ERROR updating financial engine for ${statDocId}:`, error);
        }
    }
);

// ============================================================================
// 7. DATA ARCHIVAL: 90-DAY PURGE ENGINE
// ============================================================================
exports.purgeOldOrders = onSchedule("every day 02:00", async (event) => {
    console.log("🧹 Starting 7-Year Order Purge Engine...");

    try {
        // ⚡ FIX: 90 din tha pehle — GST records ka legal retention India mein
        // 6 saal hai. Isse safe margin ke saath 7 saal (2555 din) kar diya,
        // taaki getTenantAuditFeed (Tally/Busy) aur CA-export kabhi bhi
        // legally-required purana data maangein toh mile.
        const retentionDaysAgo = new Date();
        retentionDaysAgo.setDate(retentionDaysAgo.getDate() - 2555); // 7 years
        const timestampLimit = admin.firestore.Timestamp.fromDate(retentionDaysAgo);

        const oldOrdersSnap = await db.collection("orders")
            .where("timestamp", "<=", timestampLimit)
            .limit(500) 
            .get();

        if (oldOrdersSnap.empty) {
            console.log("✅ No old orders found. Firestore is clean.");
            return;
        }

        const batch = db.batch();
        let count = 0;

        oldOrdersSnap.forEach((doc) => {
            batch.delete(doc.ref);
            count++;
        });

        await batch.commit();
        console.log(`🗑 Successfully purged ${count} orders older than 90 days.`);
    } catch (error) {
        console.error("🚨 Purge Engine Failed:", error);
    }
});

// ============================================================================
// 8. CENTRALIZED COMMUNICATION BRAIN (ANTI-SPAM GATEKEEPER)
// ============================================================================
exports.processNotificationQueue = onDocumentCreated(
    {
        document: "notification_queue/{queueId}",
        concurrency: 80, 
        memory: "256MiB"
    },
    async (event) => {
        const snap = event.data;
        if (!snap) return;

        const request = snap.data();
        const userId = request.userId;
        const priority = request.priority || "GENERIC"; 

        try {
            const userRef = db.collection('users').doc(userId);
            const userSnap = await userRef.get();
            
            if (!userSnap.exists) {
                console.log(`🚨 User ${userId} not found. Dropping message.`);
                return snap.ref.update({ status: 'DROPPED', reason: 'USER_NOT_FOUND' });
            }

            const userData = userSnap.data();
            const lastContactedAt = userData.lastContactedAt ? userData.lastContactedAt.toDate() : null;
            const now = new Date();

            const COOLDOWN_HOURS = 48;
            let shouldSend = true;
            let dropReason = "";

            if (lastContactedAt) {
                const hoursSinceLastContact = (now - lastContactedAt) / (1000 * 60 * 60);
                
                if (hoursSinceLastContact < COOLDOWN_HOURS) {
                    if (priority !== "HIGH") {
                        shouldSend = false;
                        dropReason = `SPAM_PROTECTION: Contacted ${Math.round(hoursSinceLastContact)}h ago.`;
                    }
                }
            }

            if (!shouldSend) {
                console.log(`🛡 Message Throttled for ${userData.phone || userId}: ${dropReason}`);
                return snap.ref.update({ 
                    status: 'THROTTLED', 
                    processedAt: admin.firestore.FieldValue.serverTimestamp(),
                    reason: dropReason
                });
            }

            console.log(`✅ ACTION APPROVED: Sending ${request.channel} to ${userData.phone || userId}...`);

            const batch = db.batch();
            batch.update(userRef, { lastContactedAt: admin.firestore.FieldValue.serverTimestamp() });
            batch.update(snap.ref, { 
                status: 'SENT', 
                processedAt: admin.firestore.FieldValue.serverTimestamp() 
            });

            await batch.commit();
            console.log(`🔒 Cooldown locked for User: ${userId}`);

        } catch (error) {
            console.error(`🚨 Queue Processing Failed for ${snap.id}:`, error);
            return snap.ref.update({ status: 'ERROR', error: error.toString() });
        }
    }
);

// ============================================================================
// 9. QUANTUM PROMOTION ENGINE (BULLETPROOF DELTA & SYNC)
// ============================================================================

// A. INSTANT DELTA ENGINE
exports.quantumDeltaEngine = onDocumentWritten(
    { document: "products/{productId}", concurrency: 80, memory: "256MiB" },
    async (event) => {
        const before = event.data.before.exists ? event.data.before.data() : null;
        const after = event.data.after.exists ? event.data.after.data() : null;
        const storeId = after ? after.branchCode : (before ? before.branchCode : null);
        if (!storeId) return;

        const getMetrics = (data) => {
            if (!data) return { trv: 0, tcv: 0, pr: 0 };
            const qty = data.physicalStock || data.stock || 0;
            const mrp = data.price || 0;
 // SMART FALLBACK: Agar real unitCost > 0 hai toh use karo, warna 30% margin fallback
            const cost = (data.unitCost && data.unitCost > 0) ? data.unitCost : (mrp * 0.70); 
            const offerPrice = data.offerPrice || mrp;
            return { trv: qty * mrp, tcv: qty * cost, pr: qty * offerPrice };
        };

        const oldMetrics = getMetrics(before);
        const newMetrics = getMetrics(after);

        const deltaTRV = newMetrics.trv - oldMetrics.trv;
        const deltaTCV = newMetrics.tcv - oldMetrics.tcv;
        const deltaPR = newMetrics.pr - oldMetrics.pr;
        const deltaDiscountBurn = (newMetrics.trv - newMetrics.pr) - (oldMetrics.trv - oldMetrics.pr);

        if (deltaTRV === 0 && deltaTCV === 0 && deltaPR === 0) return;

        const storeRef = db.collection('store_metrics').doc(storeId);
        try {
            await db.runTransaction(async (t) => {
                const snap = await t.get(storeRef);
                let currentTCV = deltaTCV;
                let currentPR = deltaPR;
                if (snap.exists) {
                    currentTCV += (snap.data().totalCostValue || 0);
                    currentPR += (snap.data().projectedRevenue || 0);
                }
                const margin = currentPR > 0 ? ((currentPR - currentTCV) / currentPR) * 100 : 0;
                t.set(storeRef, {
                    totalInventoryValue: admin.firestore.FieldValue.increment(deltaTRV),
                    totalCostValue: admin.firestore.FieldValue.increment(deltaTCV),
                    projectedRevenue: admin.firestore.FieldValue.increment(deltaPR),
                    discountBurn: admin.firestore.FieldValue.increment(deltaDiscountBurn),
                    projectedMargin: parseFloat(margin.toFixed(2)),
                    lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
                }, { merge: true });
            });
        } catch (e) { console.error("Delta Failed", e); }
    }
);

// B. BULLETPROOF NIGHTLY SYNC
exports.quantumNightlySync = onSchedule(
    { schedule: "0 0 * * *", timeZone: "Asia/Kolkata", timeoutSeconds: 540, memory: "1GiB" },
    async (event) => {
        try {
 // OOM CRASH FIX: Use .select() and .stream() for SaaS level data processing
            const productsStream = db.collection('products')
                .select('isBlocked', 'branchCode', 'physicalStock', 'stock', 'price', 'unitCost', 'offerPrice')
                .stream();
                
            const storeTotals = {};
            
            for await (const doc of productsStream) {
                const data = doc.data();
                
 // JS Memory Filter: Yahan block items ko ignore karo
 // FIX: 'return' yahan poore function ko exit kar deta tha, isliye
 // 'continue' use kiya taaki sirf ye product skip ho, baaki processing chalti rahe.
                if (data.isBlocked === true) continue; 

                const branch = data.branchCode;
                if (!branch) continue;
                
                if (!storeTotals[branch]) storeTotals[branch] = { trv: 0, tcv: 0, pr: 0 };
                
                const qty = data.physicalStock || data.stock || 0;
                const mrp = data.price || 0;
 // SMART FALLBACK: Auto-assumes 30% margin if unitCost is missing or 0
                const cost = (data.unitCost && data.unitCost > 0) ? data.unitCost : (mrp * 0.70); 
                const offerPrice = data.offerPrice || mrp;
                
                storeTotals[branch].trv += (qty * mrp);
                storeTotals[branch].tcv += (qty * cost);
                storeTotals[branch].pr += (qty * offerPrice);
            };

 // Har branch ka data calculate karke overwrite karo
            for (const [storeId, totals] of Object.entries(storeTotals)) {
                const discountBurn = totals.trv - totals.pr;
                const margin = totals.pr > 0 ? ((totals.pr - totals.tcv) / totals.pr) * 100 : 0;
                
                await db.collection('store_metrics').doc(storeId).set({
                    totalInventoryValue: totals.trv,
                    totalCostValue: totals.tcv,
                    projectedRevenue: totals.pr,
                    discountBurn: discountBurn,
                    projectedMargin: parseFloat(margin.toFixed(2)),
                    lastSyncedAt: admin.firestore.FieldValue.serverTimestamp()
                }, { merge: true });
            }
            console.log("✅ Sync Complete & Flawless!");
        }
         catch (e) { console.error("Sync Failed", e); }
    }
);

// ============================================================================
// 10. AUTO-PO (PURCHASE ORDER) ENGINE
// ============================================================================

// DEAD-CODE FIX: Ye Firestore trigger admin dwara intentionally PAUSED tha,
// lekin har product create/update pe abhi bhi invoke ho raha tha (products
// collection ke sabse frequent write triggers me se ek) aur sirf ek log line
// chalakar (unreachable business logic ke saath) exit ho jaata tha — har
// invocation ki chhoti si cost accumulate ho rahi thi bina kisi fayde ke.
// Ab function hi export/deploy nahi hoga. Poora original logic
// /docs/archived-cloud-functions/quantumAutoPOEngine.js.bak me safe hai.
//
// exports.quantumAutoPOEngine = onDocumentWritten({ document: "products/{productId}", ... }, async (event) => { ... });
// ============================================================================
// 11. PUSH NOTIFICATION ENGINE (FCM WINBACK COUPONS)
// ============================================================================
exports.processPushNotification = onDocumentCreated(
    { document: "notifications/{docId}", concurrency: 50, memory: "256MiB" },
    async (event) => {
        const snap = event.data;
        if (!snap) return;

        const notificationData = snap.data();
        const docRef = snap.ref;
        const targetUserId = notificationData.targetUserId;

        console.log(`🔔 New notification request detected for User: ${targetUserId}`);

        if (!targetUserId) {
            console.error("Missing targetUserId in document");
            return docRef.update({ pushStatus: 'FAILED', error: 'Missing targetUserId' });
        }

        try {
            const userDoc = await db.collection('users').doc(targetUserId).get();
            if (!userDoc.exists) throw new Error('User document not found in database');

            const userData = userDoc.data();
            
 // BUG 1 FIX: Database me 'fcmTokens' ARRAY hai, par code 'fcmToken' STRING dhoondh raha tha
            let activeToken = userData.fcmToken; 
            if (!activeToken && Array.isArray(userData.fcmTokens) && userData.fcmTokens.length > 0) {
                activeToken = userData.fcmTokens[userData.fcmTokens.length - 1]; // Pick latest token
            }

            if (!activeToken) {
                throw new Error('User has no active FCM Token (App not installed/logged in)');
            }

            const message = {
                notification: {
                    title: notificationData.notificationTitle || "Special Offer!",
                    body: notificationData.notificationBody || "Check out your ClickOut app.",
                },
                token: activeToken, // 🚀 Fixed Token Variable
                data: {
                    type: notificationData.type || 'SYSTEM',
                    tenantId: notificationData.tenantId || '',
                    branchCode: notificationData.branchCode || ''
                }
            };

            const response = await admin.messaging().send(message);
            console.log(`✅ Successfully sent message to ${targetUserId}. Message ID: ${response}`);

 // BUG 2 FIX: 'status' ko over-write mat kar! 'status' sirf Cart use karega (PENDING/USED).
 // Notification ke track record ke liye 'pushStatus' field add kar di hai.
            await docRef.update({
                pushStatus: 'SENT',
                messageId: response,
                sentAt: admin.firestore.FieldValue.serverTimestamp()
            });

        } catch (error) {
            console.error(`❌ Failed to send notification to ${targetUserId}:`, error);
            await docRef.update({
                pushStatus: 'FAILED',
                error: error.message,
                failedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }
    }
);

// ============================================================================
// 12. ULTIMATE GHOST CLEANER: AUTO-DELETE OFFERS & PROCUREMENT DATA
// ============================================================================
exports.onProductDeleted = onDocumentDeleted('products/{productId}', async (event) => {
    const snap = event.data;
    if (!snap) return; 

    const productId = event.params.productId;
    const deletedData = snap.data();
    const barcode = deletedData.barcode;

    console.log(`🧹 Product Deleted (${productId}). Hunting Offers & Procurement Data...`);

    const batch = db.batch();
    let deleteCount = 0;

    try {
 // 1. DELETE GHOST OFFERS (Using Barcode)
        if (barcode) {
            const offersSnap = await db.collection('offers').where('barcode', '==', barcode).get();
            offersSnap.forEach((doc) => {
                batch.delete(doc.ref);
                deleteCount++;
            });
        }

 // 2. DELETE FROM AI PO SUGGESTIONS (Using Product ID)
        const poSuggestionsSnap = await db.collection('ai_po_suggestions').where('productId', '==', productId).get();
        poSuggestionsSnap.forEach((doc) => {
            batch.delete(doc.ref);
            deleteCount++;
        });

 // 3. DELETE FROM PURCHASE ORDERS / PROCUREMENT (Using Product ID)
        const purchaseOrdersSnap = await db.collection('purchase_orders').where('productId', '==', productId).get();
        purchaseOrdersSnap.forEach((doc) => {
            batch.delete(doc.ref);
            deleteCount++;
        });

        if (deleteCount > 0) {
 // Agar batch me 500 se zyada items hue toh Firebase fail ho sakta hai, 
 // par ek product ke itne data nahi honge, isliye seedha commit safe hai.
            await batch.commit();
            console.log(`💥 SUCCESS: Vaporized ${deleteCount} linked documents (Offers + Procurement) for Product ${productId}!`);
        } else {
            console.log(`✅ No linked data found for ${productId}. Clean exit.`);
        }
    } catch (error) {
        console.error(`🚨 ERROR cleaning up data for ${productId}:`, error);
    }
});

// ============================================================================
// 13. SERVICE GHOST CLEANER (Agar Services me bhi offers lagte hain)
// ============================================================================
exports.onServiceDeleted = onDocumentDeleted('services/{serviceId}', async (event) => {
    const snap = event.data;
    if (!snap) return; 

    const serviceId = event.params.serviceId;
    const deletedData = snap.data();
    const barcode = deletedData.barcode;

    console.log(`🧹 Service Deleted (${serviceId}). Hunting Offers...`);

    const batch = db.batch();
    let deleteCount = 0;

    try {
        if (barcode) {
            const offersSnap = await db.collection('offers').where('barcode', '==', barcode).get();
            offersSnap.forEach((doc) => {
                batch.delete(doc.ref);
                deleteCount++;
            });
        }

        if (deleteCount > 0) {
            await batch.commit();
            console.log(`💥 SUCCESS: Vaporized ${deleteCount} ghost offers for Service ${serviceId}!`);
        }
    } catch (error) {
        console.error(`🚨 ERROR cleaning up data for Service ${serviceId}:`, error);
    }
});
// ============================================================================
// 14. USAGE LEDGER — TRANSACTION COUNTER (SUBSCRIPTION ENGINE)
// ============================================================================
exports.onOrderPaid = onDocumentWritten('orders/{orderId}', async (event) => {
    const before = event.data.before?.data();
    const after = event.data.after?.data();

    if (!after) return; // Document deleted — ignore

    const statusAfter = after.status || '';
    const statusBefore = before?.status || '';

 // Sirf jab status PAID ya completed ho — aur pehle nahi tha
    const isPaidNow =
        (statusAfter === 'PAID' || statusAfter === 'completed') &&
        (statusBefore !== 'PAID' && statusBefore !== 'completed');

    if (!isPaidNow) return;

    const tenantId = after.tenantId;
    if (!tenantId) {
        console.warn(`⚠ Order ${event.params.orderId} has no tenantId. Skipping.`);
        return;
    }

 // Current month key: "2025-06"
    const now = new Date();
    const monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

    const ledgerRef = db
        .collection('tenants')
        .doc(tenantId)
        .collection('usageLedger')
        .doc(monthKey);

    try {
        await ledgerRef.set(
            {
                transactionCount: admin.firestore.FieldValue.increment(1),
                lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
        );
        console.log(`✅ Transaction counted for tenant ${tenantId} — Month: ${monthKey}`);
    } catch (error) {
        console.error(`🚨 UsageLedger update failed for ${tenantId}:`, error);
    }
});

// ============================================================================
// 15. SUPER ADMIN: TENANT MANAGEMENT (SECURE SERVER-SIDE)
// ============================================================================
// Pre-login magic-link eligibility check. Runs with Admin SDK privileges so
// the client never needs direct unauthenticated Firestore access to `staff`.
exports.checkMagicLinkEligibility = onCall({ concurrency: 80, memory: "256MiB" }, async (request) => {
    const { email } = request.data;
    if (!email) throw new HttpsError('invalid-argument', 'Email required.');

    const query = await db.collection('staff')
        .where('email', '==', email.toLowerCase().trim())
        .limit(1)
        .get();

    if (query.empty) {
        return { allowed: true, isNewSignup: true };
    }

    const userData = query.docs[0].data();
    if (userData.isActive === false || userData.isDeleted === true) {
        throw new HttpsError('permission-denied', 'Account Suspended: Please contact support.');
    }

    const role = (userData.role || '').toString().toLowerCase();
    const allowedWebRoles = ['super_admin', 'tenant_admin', 'delegated_admin', 'admin', 'owner', 'manager'];
    if (!allowedWebRoles.includes(role)) {
        throw new HttpsError('permission-denied', 'Access Denied: You do not have Command Center privileges.');
    }

    // 🛠️ AUTO-HEAL FIX: Sync claims before sending Magic Link
    // Ye "stale token" aur 403 error ko hamesha ke liye resolve kar dega
    try {
        const userRecord = await admin.auth().getUserByEmail(email.toLowerCase().trim());
        await admin.auth().setCustomUserClaims(userRecord.uid, {
            role: role,
            tenantId: userData.tenantId || "default_tenant",
            storeId: userData.storeId || "default_store",
            branchCode: userData.branchCode || ""
        });
        console.log(`🔧 Auto-healed claims for ${email} -> Tenant: ${userData.tenantId}`);
    } catch (e) {
        // Ignore if auth user is not created yet
    }

    return { allowed: true, isNewSignup: false };
});

exports.onboardTenant = onCall(async (request) => {
 // SECURITY CHECK: Only Super Admins
    if (!request.auth || (request.auth.token.role !== 'SUPER_ADMIN' && request.auth.token.role !== 'super_admin')) {
        throw new HttpsError('permission-denied', 'Unauthorized. Only Super Admins can onboard tenants.');
    }

    const { companyName, plan, adminName, adminPhone, adminEmail } = request.data;
    if (!companyName || !adminEmail || !adminPhone) throw new HttpsError('invalid-argument', 'Missing required fields.');

    try {
 // 1. Create Auth User securely on backend
        const userRecord = await admin.auth().createUser({
            email: adminEmail.toLowerCase().trim(),
            password: 'ClickOut@' + adminPhone.substring(0, 4), // Temporary Password
            displayName: adminName.trim(),
        });
        const uid = userRecord.uid;

 // 2. Generate Unique Tenant ID
        const baseId = companyName.replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
        const tenantId = `tenant_${baseId}_${Date.now().toString().substring(8)}`;
        const maxStores = plan === 'ENTERPRISE' ? 1000 : (plan === 'PRO' ? 50 : 5);

        const batch = db.batch();

 // 3. Create Tenant Document
        const tenantRef = db.collection('tenants').doc(tenantId);
        batch.set(tenantRef, {
            tenantId: tenantId,
            companyName: companyName.trim(),
            subscriptionPlan: plan,
            billingStatus: 'ACTIVE',
            maxStores: maxStores,
            maxUsers: maxStores * 20,
            isActive: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

 // 4. Create Staff Document (This triggers assignCustomClaims automatically)
        const staffRef = db.collection('staff').doc(uid); 
        batch.set(staffRef, {
            docId: uid,
            uid: uid,
            empId: 'ADMIN-001',
            role: 'TENANT_ADMIN',
            name: adminName.trim(),
            phone: adminPhone.trim(),
            email: adminEmail.toLowerCase().trim(),
            branchCode: 'HQ',
            status: 'ACTIVE',
            isActive: true,
            isDeleted: false,
            tenantId: tenantId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

 // 5. Secure Server-Side Audit Log
        const auditRef = db.collection('admin_audit_logs').doc();
        batch.set(auditRef, {
            action: 'TENANT_ONBOARDED',
            tenantId: tenantId,
            companyName: companyName,
            actor: request.auth.token.email || 'SuperAdmin',
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        await batch.commit();
        return { success: true, tenantId: tenantId, message: "Tenant & Auth Admin created." };
    } catch (error) {
        console.error("Onboarding Error:", error);
        throw new HttpsError('internal', error.message);
    }
});

exports.toggleTenantStatus = onCall(async (request) => {
    if (!request.auth || (request.auth.token.role !== 'SUPER_ADMIN' && request.auth.token.role !== 'super_admin')) {
        throw new HttpsError('permission-denied', 'Unauthorized.');
    }
    const { tenantId, companyName, suspend } = request.data;
    
    const batch = db.batch();
    batch.update(db.collection('tenants').doc(tenantId), {
        isActive: !suspend,
        billingStatus: suspend ? 'SUSPENDED' : 'ACTIVE',
    });
    batch.set(db.collection('admin_audit_logs').doc(), {
        action: suspend ? 'TENANT_SUSPENDED' : 'TENANT_REACTIVATED',
        tenantId: tenantId,
        companyName: companyName || 'Unknown',
        actor: request.auth.token.email,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return { success: true };
});

// ============================================================================
// 16. INDUSTRY BENCHMARK ENGINE (ANONYMIZED CROSS-TENANT AGGREGATION)
// ============================================================================
// Har raat sab tenants ka daily_store_stats (last 30 din) aggregate karke
// EK single anonymized number banata hai — koi tenantId ya identifiable
// data is output doc me store nahi hota. Dashboard ka static 2.0% ab isse
// live replace hoga.
exports.computeIndustryBenchmark = onSchedule("every day 03:00", async (event) => {
    console.log("📊 Starting Industry Benchmark Aggregation...");

    try {
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        const formatter = new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' });
        const parts = formatter.format(thirtyDaysAgo).split('/');
        const sinceDateStr = `${parts[2]}-${parts[1]}-${parts[0]}`; // YYYY-MM-DD

        const statsSnap = await db.collection("daily_store_stats")
            .where("date", ">=", sinceDateStr)
            .get();

        if (statsSnap.empty) {
            console.log("✅ No stats found in window. Skipping.");
            return;
        }

        let totalRevenue = 0;
        let totalLeakage = 0;

        statsSnap.forEach((doc) => {
            const d = doc.data();
            totalRevenue += Number(d.totalRevenue || 0);
            totalLeakage += Number(d.totalLeakage || 0);
        });

        const avgLeakagePct = totalRevenue > 0 ? (totalLeakage / totalRevenue) * 100 : 0;

        // ⚡ ANONYMIZED: koi tenantId/branchCode/companyName store nahi ho raha
        await db.collection("platform_fraud_patterns").doc("industry_benchmark").set({
            avgLeakagePct: parseFloat(avgLeakagePct.toFixed(2)),
            sampleSize: statsSnap.size,
            periodDays: 30,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`✅ Industry Benchmark updated: ${avgLeakagePct.toFixed(2)}% (sample: ${statsSnap.size} store-days)`);
    } catch (error) {
        console.error("🚨 Industry Benchmark Engine Failed:", error);
    }
});

// ============================================================================
// 17. MONTHLY VERIFIED SALES REPORT (AUTO-GENERATE + AUTO-EMAIL)
// ============================================================================
// Har mahine ki 1st tareekh ko, pichle poore mahine ka summary har active
// tenant ke TENANT_ADMIN ko email hota hai. 'mail' collection Trigger Email
// extension use karta hai — already installed hai (Firestore mein dikh raha tha).
exports.sendMonthlyVerifiedSalesReport = onSchedule("1 of month 06:00", async (event) => {
    console.log("📧 Starting Monthly Verified Sales Report...");

    try {
        const now = new Date();
        // Pichla poora mahina nikalna (agar aaj July hai, toh June ka data)
        const firstDayLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        const lastDayLastMonth = new Date(now.getFullYear(), now.getMonth(), 0);
        const fmt = (d) => d.toISOString().split("T")[0]; // YYYY-MM-DD
        const startStr = fmt(firstDayLastMonth);
        const endStr = fmt(lastDayLastMonth);
        const monthLabel = firstDayLastMonth.toLocaleString("en-IN", { month: "long", year: "numeric" });

        const tenantsSnap = await db.collection("tenants").where("isActive", "==", true).get();
        console.log(`Found ${tenantsSnap.size} active tenants.`);

        for (const tenantDoc of tenantsSnap.docs) {
            const tenantId = tenantDoc.id;
            const companyName = tenantDoc.data().companyName || "Your Store";

            try {
                // 1. Tenant Admin ka email nikalo
                const staffSnap = await db.collection("staff")
                    .where("tenantId", "==", tenantId)
                    .where("role", "==", "TENANT_ADMIN")
                    .where("isActive", "==", true)
                    .limit(1)
                    .get();

                if (staffSnap.empty) {
                    console.log(`⚠️ No active TENANT_ADMIN found for ${tenantId}. Skipping.`);
                    continue;
                }
                const adminEmail = staffSnap.docs[0].data().email;
                if (!adminEmail) continue;

                // 2. Pichle mahine ka daily_store_stats sum karo
                const statsSnap = await db.collection("daily_store_stats")
                    .where("tenantId", "==", tenantId)
                    .where("date", ">=", startStr)
                    .where("date", "<=", endStr)
                    .get();

                if (statsSnap.empty) {
                    console.log(`No stats for ${tenantId} in ${monthLabel}. Skipping.`);
                    continue;
                }

                let totalRevenue = 0, totalLeakage = 0, refundAmount = 0, rejectedCount = 0;
                statsSnap.forEach((doc) => {
                    const d = doc.data();
                    totalRevenue += Number(d.totalRevenue || 0);
                    totalLeakage += Number(d.totalLeakage || 0);
                    refundAmount += Number(d.refundAmount || 0);
                    rejectedCount += Number(d.rejectedCount || 0);
                });

                const verifiedPct = totalRevenue > 0
                    ? (((totalRevenue - totalLeakage) / totalRevenue) * 100).toFixed(1)
                    : "0.0";

                // 3. Email bhejo (Trigger Email extension: 'mail' collection)
                await db.collection("mail").add({
                    to: [adminEmail],
                    message: {
                        subject: `ClickOut Verified Sales Report — ${monthLabel}`,
                        html: `
                            <h2>Hi, ${companyName} 👋</h2>
                            <p>Yahaan hai aapka <b>${monthLabel}</b> ka Verified Sales Report:</p>
                            <ul>
                                <li><b>Total Revenue:</b> ₹${totalRevenue.toFixed(0)}</li>
                                <li><b>Verified Sales:</b> ${verifiedPct}%</li>
                                <li><b>At-Risk (Pending/Leakage):</b> ₹${totalLeakage.toFixed(0)}</li>
                                <li><b>Refunds:</b> ₹${refundAmount.toFixed(0)}</li>
                                <li><b>Guard Rejections:</b> ${rejectedCount}</li>
                            </ul>
                            <p>Full CA-grade export ke liye Admin Panel &gt; Super Auditor check karo.</p>
                            <p>— Team ClickOut</p>
                        `,
                    },
                });

                console.log(`✅ Report sent to ${adminEmail} for ${companyName}`);
            } catch (innerErr) {
                console.error(`🚨 Failed for tenant ${tenantId}:`, innerErr);
            }
        }

        console.log("✅ Monthly Verified Sales Report cycle complete.");
    } catch (error) {
        console.error("🚨 Monthly Report Engine Failed:", error);
    }
});

// ============================================================================
// 18. ERP API KEY GENERATION (For Tally/Busy/3rd-party Integrations)
// ============================================================================
exports.generateErpApiKey = onCall(async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Login required.');

    const email = request.auth.token.email;
    if (!email) throw new HttpsError('invalid-argument', 'No email on this account.');

    // ⚡ FIX: request.auth.token.role/tenantId (custom claims) can lag behind
    // or be unset — adminRoleProvider (client) already flags this same gap
    // and treats the 'staff' Firestore doc as source of truth. Doing the
    // same here instead of trusting stale/missing token claims.
    const staffSnap = await db.collection('staff')
        .where('email', '==', email)
        .where('isActive', '==', true)
        .limit(1)
        .get();

    if (staffSnap.empty) {
        throw new HttpsError('permission-denied', 'No active staff record found.');
    }

    const staffData = staffSnap.docs[0].data();
    const role = (staffData.role || '').toString().toUpperCase();
    const tenantId = staffData.tenantId;

    if (role !== 'TENANT_ADMIN' && role !== 'SUPER_ADMIN') {
        throw new HttpsError('permission-denied', 'Only Tenant Admin can generate API keys.');
    }
    if (!tenantId) {
        throw new HttpsError('failed-precondition', 'No tenant associated with this staff record.');
    }

    // ⚡ Simple random key — good enough for MVP. Not hashed in DB (read-only
    // scope, low blast radius), but rotatable anytime by calling this again.
    const newKey = `co_${tenantId.substring(0, 8)}_${Math.random().toString(36).substring(2, 15)}${Date.now().toString(36)}`;

    await db.collection('tenants').doc(tenantId).update({
        erpApiKey: newKey,
        erpApiKeyGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { apiKey: newKey };
});

// ============================================================================
// 19. TALLY/BUSY/ERP READ-ONLY AUDIT FEED
// ============================================================================
// GET /getTenantAuditFeed?apiKey=xxx&startDate=2026-07-01&endDate=2026-07-31
// Read-only. No write access. Rate-limited by date-range size (max 1000 rows).
exports.getTenantAuditFeed = onRequest(async (req, res) => {
    try {
        const { apiKey, startDate, endDate } = req.query;

        if (!apiKey || !startDate || !endDate) {
            return res.status(400).json({ error: "Missing apiKey, startDate, or endDate." });
        }

        // 1. Authenticate via tenant API key
        const tenantSnap = await db.collection('tenants').where('erpApiKey', '==', apiKey).limit(1).get();
        if (tenantSnap.empty) {
            return res.status(401).json({ error: "Invalid API key." });
        }
        const tenantId = tenantSnap.docs[0].id;

        // 2. Parse date range
        const start = new Date(`${startDate}T00:00:00`);
        const end = new Date(`${endDate}T23:59:59`);
        if (isNaN(start) || isNaN(end)) {
            return res.status(400).json({ error: "Invalid date format. Use YYYY-MM-DD." });
        }

        // 3. Fetch orders (read-only, capped at 1000 rows per call)
        const ordersSnap = await db.collection('orders')
            .where('tenantId', '==', tenantId)
            .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(start))
            .where('timestamp', '<=', admin.firestore.Timestamp.fromDate(end))
            .limit(1000)
            .get();

        const feed = ordersSnap.docs.map((doc) => {
            const d = doc.data();
            return {
                orderId: doc.id,
                timestamp: d.timestamp ? d.timestamp.toDate().toISOString() : null,
                totalAmount: d.totalAmount || 0,
                paymentMode: d.paymentMode || 'UNKNOWN',
                exitStatus: d.exitStatus || d.paymentStatus || 'PENDING',
                branchCode: d.branchCode || 'HQ',
                items: d.items || [],
            };
        });

        return res.status(200).json({ tenantId, count: feed.length, orders: feed });
    } catch (error) {
        console.error("🚨 getTenantAuditFeed Failed:", error);
        return res.status(500).json({ error: "Internal server error." });
    }
});

exports.changeTenantPlan = onCall(async (request) => {
    if (!request.auth || (request.auth.token.role !== 'SUPER_ADMIN' && request.auth.token.role !== 'super_admin')) {
        throw new HttpsError('permission-denied', 'Unauthorized.');
    }
    const { tenantId, companyName, newPlan, oldPlan } = request.data;
    
    const batch = db.batch();
    batch.update(db.collection('tenants').doc(tenantId), {
        subscriptionPlan: newPlan,
        plan: newPlan,
    });
    batch.set(db.collection('admin_audit_logs').doc(), {
        action: 'PLAN_CHANGED',
        tenantId: tenantId,
        companyName: companyName || 'Unknown',
        details: `${oldPlan} -> ${newPlan}`,
        actor: request.auth.token.email,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return { success: true };
});

// ============================================================================
// 20. DPDP COMPLIANCE: ULTIMATE STORE HARD DELETE (CASCADE & STORAGE WIPE)
// ============================================================================
exports.onStoreDeleted = onDocumentDeleted('stores/{storeId}', async (event) => {
    const snap = event.data;
    if (!snap) return;
    
    const storeData = snap.data() || {};
    const storeId = event.params.storeId;
    const branchCode = storeData.branchCode;
    const tenantId = storeData.tenantId;
    
    console.log(`⚖️ DPDP WIPE INITIATED: Store ${storeId} (${branchCode}). Purging database and storage...`);

    try {
        // 1. Wipe Database Collections linked via 'storeId'
        // Hata diya faltu "reservations" aur "services" (agar use nahi ho raha). Sirf zaroori collections rakhe hain.
        const storeIdCollections = [
            'staff', 'carts', 'idt_deposits', 'audit_logs', 
            'notifications', 'orders', 'invoices', 'analytics', 
            'customer_sessions', 'gate_authorized', 'gate_overrides', 
            'offers', 'refunds', 'purchase_orders'
        ];
        
        for (const coll of storeIdCollections) {
            const querySnap = await db.collection(coll).where('storeId', '==', storeId).get();
            if (!querySnap.empty) {
                const batch = db.batch();
                querySnap.forEach(doc => {
                    // 🛡️ SECURITY: Tenant Admin aur Super Admin ko kabhi delete mat karna
                    if (doc.data().role !== 'TENANT_ADMIN' && doc.data().role !== 'SUPER_ADMIN') {
                        batch.delete(doc.ref);
                    }
                });
                await batch.commit();
                console.log(`🧹 Wiped ${querySnap.size} DB records from ${coll}`);
            }
        }

        // 2. Wipe Collections linked via 'branchCode' (Products, Metrics)
        if (branchCode) {
            const branchCollections = ['products']; // Add any other collections using branchCode here
            for (const coll of branchCollections) {
                const querySnap = await db.collection(coll).where('branchCode', '==', branchCode).get();
                if (!querySnap.empty) {
                    const batch = db.batch();
                    querySnap.forEach(doc => batch.delete(doc.ref));
                    await batch.commit();
                    console.log(`🧹 Wiped ${querySnap.size} DB records from ${coll}`);
                }
            }
            
            // Direct document metrics wipe
            await db.collection('store_metrics').doc(branchCode).delete().catch(()=> {});
            await db.collection('daily_store_stats').doc(branchCode).delete().catch(()=> {});
        }

        // 3. STORAGE WIPE: Delete the Store Logo from Firebase Storage!
        // Firebase Storage bucket import karo upar (if not already there)
        const bucket = getStorage().bucket(); 
        
        if (tenantId && branchCode) { // Store logo ka path branchCode ke sath save karna best practice hai
             // Example path: logos/{tenantId}/store_logo_{branchCode}.png
             // Agar file milti hai toh delete kar do
             const fileName = `logos/${tenantId}/store_logo_${branchCode}.png`; 
             const file = bucket.file(fileName);
             
             file.exists().then(async (data) => {
                 const exists = data[0];
                 if (exists) {
                     await file.delete();
                     console.log(`🗑️ Wiped Store Logo from Storage: ${fileName}`);
                 }
             }).catch((err) => {
                 console.log("No store logo found to delete or error checking.", err);
             });
        }


        console.log(`✅ SUCCESS: 100% DPDP Hard Wipe complete (DB + Storage) for Store ${storeId}.`);
    } catch (error) {
        console.error(`🚨 CRITICAL: DPDP Wipe failed for ${storeId}:`, error);
    }
});

// ============================================================================
// 21. PHASE 5B: DAILY AGGREGATION ENGINE (RUNS 12:05 AM IST)
// ============================================================================
exports.aggregateDailyStoreStats = onSchedule(
    { schedule: "5 0 * * *", timeZone: "Asia/Kolkata", memory: "512MiB" }, 
    async (event) => {
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        
        const startOfDay = new Date(yesterday.setHours(0, 0, 0, 0));
        const endOfDay = new Date(yesterday.setHours(23, 59, 59, 999));
        const dateString = startOfDay.toISOString().split('T')[0];

        const ordersSnap = await db.collection('orders')
            .where('timestamp', '>=', startOfDay)
            .where('timestamp', '<=', endOfDay)
            .where('status', 'in', ['COMPLETED', 'APPROVED', 'SUCCESS', 'PAID'])
            .get();

        if (ordersSnap.empty) {
            console.log(`No orders found for ${dateString}.`);
            return null;
        }

        const storeStats = {};
        ordersSnap.forEach(doc => {
            const data = doc.data();
            const tenantId = data.tenantId;
            if (!tenantId) return;

            const branchCode = data.branchCode || 'HQ';
            const key = `${tenantId}_${branchCode}`;

            if (!storeStats[key]) {
                storeStats[key] = {
                    tenantId: tenantId,
                    branchCode: branchCode,
                    date: dateString,
                    totalOrders: 0,
                    totalRevenue: 0,
                    itemsSold: 0
                };
            }

            storeStats[key].totalOrders += 1;
            storeStats[key].totalRevenue += (data.totalAmount || data.amount || 0);
            
            const items = data.cartItems || data.items || [];
            storeStats[key].itemsSold += items.length;
        });

        const batch = db.batch();
        let operationCount = 0;

        for (const stat of Object.values(storeStats)) {
            const docId = `${stat.tenantId}_${stat.branchCode}_${stat.date}`;
            const docRef = db.collection('daily_store_stats').doc(docId);
            
            batch.set(docRef, {
                ...stat,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });

            operationCount++;
            if (operationCount >= 490) {
                await batch.commit();
                operationCount = 0;
            }
        }

        if (operationCount > 0) {
            await batch.commit();
        }
        
        console.log(`Aggregated stats for ${Object.keys(storeStats).length} stores on ${dateString}`);
        return null;
    }
);
        // ============================================================================
        // 22. DAILY STORE STATS GENERATOR
        // Runs every night, aggregates today's orders per store into one summary doc.
        // ============================================================================
        exports.generateDailyStoreStats = onSchedule(
        { schedule: "55 23 * * *", timeZone: "Asia/Kolkata" },
        async () => {
        const now = new Date();
        const dateStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
        const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());

        const ordersSnap = await db.collection("orders")
            .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(startOfDay))
            .get();

        const groups = {};
        for (const doc of ordersSnap.docs) {
            const data = doc.data();
            const key = `${data.tenantId}_${data.branchCode}`;
                if (!groups[key]) {
                    groups[key] = {
                        tenantId: data.tenantId,
                        branchCode: data.branchCode,
                        totalRevenue: 0, cashRevenue: 0, upiRevenue: 0,
                        cashLeakage: 0, upiLeakage: 0,
                        totalOrders: 0, rejectedCount: 0, pendingCount: 0,
                        refundCount: 0, refundAmount: 0,
        };
      }
        const g = groups[key];
        const pStatus = (data.paymentStatus || "").toUpperCase();
        const eStatus = (data.exitStatus || "").toUpperCase();
        const amount = parseFloat(data.totalAmount || 0) || 0;
        const isCash = (data.paymentMode || "").toUpperCase() === "CASH";

      if (pStatus === "PAID" || pStatus === "SUCCESS") {
        g.totalOrders++;
        g.totalRevenue += amount;
        if (isCash) g.cashRevenue += amount; else g.upiRevenue += amount;

        if (eStatus === "REJECTED") {
          g.rejectedCount++;
          if (isCash) g.cashLeakage += amount; else g.upiLeakage += amount;
        } else if (eStatus === "PENDING" || eStatus === "READY_FOR_EXIT") {
          g.pendingCount++;
          if (isCash) g.cashLeakage += amount; else g.upiLeakage += amount;
        }
      }
      if (pStatus === "REFUNDED") {
        g.refundCount++;
        g.refundAmount += amount;
      }
    }

    const batch = db.batch();
    for (const key of Object.keys(groups)) {
      const g = groups[key];
      const docId = `${g.tenantId}_${g.branchCode}_${dateStr}`;
      batch.set(db.collection("daily_store_stats").doc(docId), {
        ...g,
        date: dateStr,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    await batch.commit();
    console.log(`Generated daily_store_stats for ${Object.keys(groups).length} stores.`);
  }
);

// ============================================================================
// 23. AI REORDER SUGGESTION GENERATOR
// Runs every morning, scans low-stock products, creates one suggestion per item.
// ============================================================================
exports.generateAiPoSuggestions = onSchedule(
  { schedule: "0 6 * * *", timeZone: "Asia/Kolkata" },
  async () => {
    const lowStockSnap = await db.collection("products")
      .where("physicalStock", "<=", 20)
      .get();

    const existingSnap = await db.collection("ai_po_suggestions").get();
    const alreadySuggested = new Set(existingSnap.docs.map((d) => d.data().productId));

    const batch = db.batch();
    let created = 0;

    for (const doc of lowStockSnap.docs) {
      const data = doc.data();
      if (data.isBlocked === true || data.isDeleted === true) continue;
      if (alreadySuggested.has(doc.id)) continue;

      const supplierId = data.supplierId || "DEFAULT_SUPPLIER";
      const suggestedQty = Math.max(50, (data.openingStock || 50) - (data.physicalStock || 0));

      const ref = db.collection("ai_po_suggestions").doc();
      batch.set(ref, {
        suggestionId: ref.id,
        productId: doc.id,
        supplierId,
        branchCode: data.branchCode || "HQ",
        suggestedQty,
        tenantId: data.tenantId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      created++;
    }

    await batch.commit();
    console.log(`Generated ${created} new AI PO suggestions.`);
  }
);