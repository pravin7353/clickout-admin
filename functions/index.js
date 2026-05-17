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
        // 🚀 MEMORY FIX 1: Use .select() to only fetch required fields (saves ~90% RAM)
        const productsSnap = await db.collection("products")
            .where("isBlocked", "==", false)
            .select("physicalStock", "supplierId", "avgDailySales", "supplierLeadTime", "safetyBuffer", "name", "tenantId", "branchCode", "storeId")
            .get();
        
        // 🚀 MEMORY FIX 2: Only fetch productId for existing suggestions
        const existingSuggestions = await db.collection("ai_po_suggestions")
            .where("status", "==", "PENDING_APPROVAL")
            .select("productId") 
            .get();
        const existingProductIds = new Set();
        existingSuggestions.forEach(doc => existingProductIds.add(doc.data().productId));

        let suggestionsCount = 0;
        
        // 🚀 BATCH LIMIT FIX PREP: Create an array for multiple batches
        const batches = [];
        let currentBatch = db.batch();
        let currentBatchCount = 0;

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
                currentBatch.set(suggestionRef, {
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
                currentBatchCount++;

                // 🚀 BATCH CRASH AVOIDANCE: Commit when limit is near
                if (currentBatchCount >= 490) {
                    batches.push(currentBatch.commit());
                    currentBatch = db.batch();
                    currentBatchCount = 0;
                }
            }
        }

        if (currentBatchCount > 0) {
            batches.push(currentBatch.commit());
        }

        if (batches.length > 0) {
            await Promise.all(batches);
            console.log(`✅ AI Engine Generated ${suggestionsCount} NEW PO Suggestions via ${batches.length} safe batches!`);
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
// 📈 6. QUANTUM FINANCIAL ENGINE (O(1) DASHBOARD AGGREGATOR)
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

        // 🕒 IST Timezone Fix for Accurate Daily Reset
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

        // 🧠 DELTA MATH: Handles PENDING -> PAID transitions automatically!
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
            // 🚀 OOM CRASH FIX: Use .select() and .stream() for SaaS level data processing
            const productsStream = db.collection('products')
                .select('isBlocked', 'branchCode', 'physicalStock', 'stock', 'price', 'unitCost', 'offerPrice')
                .stream();
                
            const storeTotals = {};
            
            for await (const doc of productsStream) {
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
            
            // 🚀 BUG 1 FIX: Database me 'fcmTokens' ARRAY hai, par code 'fcmToken' STRING dhoondh raha tha
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

            // 🚀 BUG 2 FIX: 'status' ko over-write mat kar! 'status' sirf Cart use karega (PENDING/USED).
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
// 🗑️ 12. ULTIMATE GHOST CLEANER: AUTO-DELETE OFFERS & PROCUREMENT DATA
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
        // 🎯 1. DELETE GHOST OFFERS (Using Barcode)
        if (barcode) {
            const offersSnap = await db.collection('offers').where('barcode', '==', barcode).get();
            offersSnap.forEach((doc) => {
                batch.delete(doc.ref);
                deleteCount++;
            });
        }

        // 🎯 2. DELETE FROM AI PO SUGGESTIONS (Using Product ID)
        const poSuggestionsSnap = await db.collection('ai_po_suggestions').where('productId', '==', productId).get();
        poSuggestionsSnap.forEach((doc) => {
            batch.delete(doc.ref);
            deleteCount++;
        });

        // 🎯 3. DELETE FROM PURCHASE ORDERS / PROCUREMENT (Using Product ID)
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
// 🗑️ 13. SERVICE GHOST CLEANER (Agar Services me bhi offers lagte hain)
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