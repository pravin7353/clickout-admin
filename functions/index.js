const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
// 🚀 NAYA: onDocumentWritten aur onDocumentCreated imports add kiye hain
const { onDocumentDeleted, onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer"); // 🚀 ADDED NODEMAILER

admin.initializeApp();
const db = admin.firestore();

// 📧 SMTP Configuration (Testing k liye yaha apna Gmail aur App Password dalein)
const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: 'YOUR_EMAIL@gmail.com', // ⚠️ ISE CHANGE KAREIN
        pass: 'YOUR_16_DIGIT_APP_PASSWORD' // ⚠️ ISE CHANGE KAREIN
    }
});

// ============================================================================
// 📦 1. BULK IMPORT PRODUCTS (UPGRADED TO GEN 2 🚀 - SAAS ISOLATED)
// ============================================================================
exports.bulkImportProducts = onCall(async (request) => {
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

            // 🚀 SAAS ISOLATION: Naya Document ID Format
            const tenantId = prod.tenantId || "RESTRICTED";
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
                price: safePrice,
                unitCost: parseFloat(safeUnitCost.toFixed(2)), // 🚀 FIX: Now properly references the parsed variable
                weight: safeWeight,
                gst: String(prod.gst || "0").trim(),
                isBlocked: false, // 🚀 FIX: Ab koi product invisible nahi rahega!                physicalStock: safeStock,
                openingStock: safeStock,
                purchasedStock: 0,
                soldStock: 0,
                damagedStock: 0,
                expiredStock: 0,
                reservedStock: 0,
                searchKey: String(prod.name || "Unknown Item").toLowerCase().trim(),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                // 🚀 NEW: SAAS & FRAUD TRACKING FIELDS INJECTED
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

        await Promise.all(batches);

        return { success: true, message: `Mission Accomplished: ${totalImported} Master SKUs isolated & added to the Vault!` };

    } catch (error) {
        console.error("CRITICAL CRASH: ", error);
        throw new HttpsError('unknown', `CRASH REPORT: ${error.message}`);
    }
});


// ============================================================================
// 🤖 2. PREDICTIVE AUTO-PO ENGINE (GEN 2 - FIXED DUPLICATES & SMART MATH)
// ============================================================================
exports.runPredictivePOEngine = onSchedule("every day 00:00", async (event) => {
    console.log("🚀 Starting ClickOut Predictive AI Engine...");
    
    try {
        // 1. Fetch all active products
const productsSnap = await db.collection("products").where("isBlocked", "==", false).get();
        
        // 🚀 FIX 1: Fetch existing suggestions to prevent DUPLICATE SPAM
        const existingSuggestions = await db.collection("ai_po_suggestions")
            .where("status", "==", "PENDING_APPROVAL")
            .get();
        const existingProductIds = new Set();
        existingSuggestions.forEach(doc => existingProductIds.add(doc.data().productId));

        let suggestionsCount = 0;
        const batch = db.batch();

        for (const doc of productsSnap.docs) {
            // 🚀 If already suggested and pending, skip it!
            if (existingProductIds.has(doc.id)) continue; 

            const data = doc.data();
            const physicalStock = data.physicalStock || 0;
            const supplierId = data.supplierId || "DEFAULT_SUPPLIER";
            
            const dailyVelocity = data.avgDailySales || 5; 
            const leadTimeDays = data.supplierLeadTime || 3; 
            const safetyBuffer = data.safetyBuffer || 20;    
            
            const reorderPoint = (dailyVelocity * leadTimeDays) + safetyBuffer;

         if (physicalStock <= reorderPoint) {
                let orderQty = Math.ceil((dailyVelocity * 14) - physicalStock);
                // 🚀 FIX: Fallback to at least 10 units. Prevents null, NaN, or 0.
                orderQty = Math.max(10, orderQty || 10); 
                
                const suggestionRef = db.collection("ai_po_suggestions").doc();
                batch.set(suggestionRef, {
                    suggestionId: suggestionRef.id,
                    productId: doc.id,
                    productName: data.name || "Unknown Product",
                    tenantId: data.tenantId || "default_tenant",
                    branchCode: data.branchCode || data.storeId || "HQ",
                    currentStock: physicalStock,
                    recommendedQty: orderQty, // 🚀 100% Safe value
                    supplierId: supplierId,
                    reason: `Stock (${physicalStock}) hit Re-Order Point (${reorderPoint}). Velocity: ${dailyVelocity}/day.`,
                    status: "PENDING_APPROVAL", // 🚀 Strict Status Enforced
                    createdAt: admin.firestore.FieldValue.serverTimestamp()
                });
                suggestionsCount++;
            }
        }

        if (suggestionsCount > 0) {
            await batch.commit();
            console.log(`✅ AI Engine Generated ${suggestionsCount} NEW PO Suggestions!`);
        } else {
            console.log("👍 Stock is perfectly healthy. No suggestions today.");
        }
    } catch (error) {
        console.error("🚨 Predictive Engine Failed: ", error);
    }
});

// ============================================================================
// 🧹 3. ADMIN SDK: AUTO-DELETE AUTH USER (UPGRADED TO GEN 2 🚀)
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
            console.log(`⚠️ User ${uid} already deleted from Auth.`);
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
            console.log(`⚠️ User ${uid} already deleted from Auth.`);
        } else {
            console.error(`🚨 ERROR deleting auth user ${uid}:`, error);
        }
    }
});

// ============================================================================
// 🛡️ 4. SAAS RBAC: CUSTOM CLAIMS INJECTOR
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
// ⚡ 5. DECOUPLED ORDER PROCESSOR & FRAUD ENGINE
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
        }
    }
);

// ============================================================================
// 📈 6. REAL-TIME ANALYTICS AGGREGATOR (10M SCALE READY)
// ============================================================================
exports.updateDailyStats = onDocumentCreated(
    {
        document: "orders/{orderId}",
        concurrency: 80, 
        memory: "256MiB" 
    }, 
    async (event) => {
        const orderData = event.data?.data();
        if (!orderData) return;

        const tenantId = orderData.tenantId || "default_tenant";
        const storeId = orderData.storeId || "default_store";
        const totalAmount = Number(orderData.totalAmount || orderData.getTotal || 0);
        
        let isFraud = 0;
        if (orderData.weightMismatchFlag || orderData.exitStatus === 'OVERRIDDEN') {
            isFraud = 1;
        }

        const dateObj = new Date();
        const dateStr = dateObj.toISOString().split('T')[0]; 
        
        const statDocId = `${storeId}_${dateStr}`;
        const statRef = db.collection("daily_store_stats").doc(statDocId);

        try {
            await statRef.set({
                tenantId: tenantId,
                storeId: storeId,
                date: dateStr,
                metrics: {
                    totalOrders: admin.firestore.FieldValue.increment(1),
                    totalRevenue: admin.firestore.FieldValue.increment(totalAmount),
                    fraudAlerts: admin.firestore.FieldValue.increment(isFraud)
                },
                lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });
            
            console.log(`📊 Stats updated for Store: ${storeId} on ${dateStr}`);
        } catch (error) {
            console.error(`🚨 ERROR updating stats for ${storeId}:`, error);
        }
    }
);

// ============================================================================
// 🗑️ 7. DATA ARCHIVAL: 90-DAY PURGE ENGINE
// ============================================================================
exports.purgeOldOrders = onSchedule("every day 02:00", async (event) => {
    console.log("🧹 Starting 90-Day Order Purge Engine...");
    
    try {
        const ninetyDaysAgo = new Date();
        ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);
        const timestampLimit = admin.firestore.Timestamp.fromDate(ninetyDaysAgo);

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
        console.log(`🗑️ Successfully purged ${count} orders older than 90 days.`);
    } catch (error) {
        console.error("🚨 Purge Engine Failed:", error);
    }
});

// ============================================================================
// 🧠 8. CENTRALIZED COMMUNICATION BRAIN (ANTI-SPAM GATEKEEPER)
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
                console.log(`🛡️ Message Throttled for ${userData.phone || userId}: ${dropReason}`);
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
// 🔮 9. QUANTUM PROMOTION ENGINE (BULLETPROOF DELTA & SYNC)
// ============================================================================

// ⚡ A. INSTANT DELTA ENGINE
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
            // 🧠 SMART FALLBACK: Agar real unitCost > 0 hai toh use karo, warna 30% margin fallback
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

// 🧹 B. BULLETPROOF NIGHTLY SYNC
exports.quantumNightlySync = onSchedule(
    { schedule: "0 0 * * *", timeZone: "Asia/Kolkata", timeoutSeconds: 540, memory: "1GiB" },
    async (event) => {
        try {
            // 🚀 THE NOSQL TRAP FIX: Saare products laao (bina where clause ke)
            const productsSnap = await db.collection('products').get();
            const storeTotals = {};
            
            productsSnap.forEach(doc => {
                const data = doc.data();
                
                // 🧠 JS Memory Filter: Yahan block items ko ignore karo
                if (data.isBlocked === true) return; 

                const branch = data.branchCode;
                if (!branch) return;
                
                if (!storeTotals[branch]) storeTotals[branch] = { trv: 0, tcv: 0, pr: 0 };
                
                const qty = data.physicalStock || data.stock || 0;
                const mrp = data.price || 0;
                // 🧠 SMART FALLBACK: Auto-assumes 30% margin if unitCost is missing or 0
                const cost = (data.unitCost && data.unitCost > 0) ? data.unitCost : (mrp * 0.70); 
                const offerPrice = data.offerPrice || mrp;
                
                storeTotals[branch].trv += (qty * mrp);
                storeTotals[branch].tcv += (qty * cost);
                storeTotals[branch].pr += (qty * offerPrice);
            });

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
        } catch (e) { console.error("Sync Failed", e); }
    }
);

// ============================================================================
// 🛒 10. AUTO-PO (PURCHASE ORDER) ENGINE
// ============================================================================

exports.quantumAutoPOEngine = onDocumentWritten(
    { document: "products/{productId}", concurrency: 50, memory: "256MiB" },
    async (event) => {
        const after = event.data.after.exists ? event.data.after.data() : null;
        if (!after || after.isBlocked) return;

        const productId = event.params.productId;
        const currentStock = after.physicalStock || after.stock || 0;
        const minStock = after.minStockLevel || 10; // Default threshold

        // Only trigger if stock is dangerously low
        if (currentStock > minStock) return;

        const branchCode = after.branchCode;
        const tenantId = after.tenantId;
        if (!branchCode || !tenantId) return;

        const poRef = db.collection('purchase_orders');
        
        try {
            await db.runTransaction(async (t) => {
                // Check if a pending PO already exists for this product to avoid duplicates
                const existingPOQuery = await t.get(
                    poRef.where('productId', '==', productId)
                         .where('status', '==', 'PENDING')
                         .where('branchCode', '==', branchCode)
                         .limit(1)
                );

                if (!existingPOQuery.empty) return; // PO already waiting for manager approval

                // Draft a new automated PO
                const autoOrderQty = (after.maxStockLevel || 50) - currentStock; 
                if (autoOrderQty <= 0) return;

                const newPODoc = poRef.doc();
                t.set(newPODoc, {
                    poId: `PO-${Date.now()}`,
                    productId: productId,
                    productName: after.name,
                    barcode: after.barcode,
                    branchCode: branchCode,
                    tenantId: tenantId,
                    currentStock: currentStock,
                    suggestedOrderQty: autoOrderQty,
                    unitCost: (after.unitCost && after.unitCost > 0) ? after.unitCost : ((after.price || 0) * 0.70), // Safe Fallback cost
                    status: 'PENDING',
                    generatedBy: 'QUANTUM_AI',
                    createdAt: admin.firestore.FieldValue.serverTimestamp()
                });
            });
            console.log(`Auto-PO Drafted for ${after.name} at branch ${branchCode}`);
        } catch (error) {
            console.error("Auto-PO Engine Failed:", error);
        }
    }
);
// ============================================================================
// 🔔 11. PUSH NOTIFICATION ENGINE (FCM WINBACK COUPONS)
// ============================================================================
exports.processPushNotification = onDocumentCreated(
    { document: "notifications/{docId}", concurrency: 50, memory: "256MiB" },
    async (event) => {
        // 1. Naya document jo create hua hai, uska data lijiye
        const snap = event.data;
        if (!snap) return;

        const notificationData = snap.data();
        const docRef = snap.ref;
        const targetUserId = notificationData.targetUserId;

        console.log(`🔔 New notification request detected for User: ${targetUserId}`);

        // Agar targetUserId missing hai, toh fail mark kardo
        if (!targetUserId) {
            console.error("Missing targetUserId in document");
            return docRef.update({ status: 'FAILED', error: 'Missing targetUserId' });
        }

        try {
            // 2. Fetch target user's details to get their FCM Token
            const userDoc = await db.collection('users').doc(targetUserId).get();
            
            if (!userDoc.exists) {
                throw new Error('User document not found in database');
            }

            const userData = userDoc.data();
            const fcmToken = userData.fcmToken; // ⚠️ CLIENT APP MUST SAVE THIS TOKEN HERE

            if (!fcmToken) {
                throw new Error('User has no active FCM Token (App not installed/logged in)');
            }

            // 3. Create the FCM Payload
            const message = {
                notification: {
                    title: notificationData.notificationTitle || "Special Offer!",
                    body: notificationData.notificationBody || "Check out your ClickOut app.",
                },
                token: fcmToken,
                data: {
                    type: notificationData.type || 'SYSTEM',
                    tenantId: notificationData.tenantId || '',
                    branchCode: notificationData.branchCode || ''
                }
            };

            // 4. Send the Push Notification via Firebase Admin Messaging
            const response = await admin.messaging().send(message);
            console.log(`✅ Successfully sent message to ${targetUserId}. Message ID: ${response}`);

            // 5. Update the original notification document to 'SENT'
            await docRef.update({
                status: 'SENT',
                messageId: response,
                sentAt: admin.firestore.FieldValue.serverTimestamp()
            });

        } catch (error) {
            console.error(`❌ Failed to send notification to ${targetUserId}:`, error);
            await docRef.update({
                status: 'FAILED',
                error: error.message,
                failedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }
    }
);