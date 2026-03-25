const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
// 🚀 NAYA: onDocumentWritten aur onDocumentCreated imports add kiye hain
const { onDocumentDeleted, onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// ============================================================================
// 📦 1. BULK IMPORT PRODUCTS (UPGRADED TO GEN 2 🚀)
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

        const batch = db.batch();
        let count = 0;

        for (const prod of products) {
            if (!prod || !prod.barcode) continue; 

            const barcode = String(prod.barcode).trim();
            const docRef = db.collection('products').doc(barcode);

            const safePrice = Number(prod.price) || 0;
            const safeWeight = String(prod.weight || "");
            const safeStock = Number(prod.stock) || 0;

            const cleanData = {
                barcode: barcode,
                name: String(prod.name || "Unknown Item").trim(),
                price: safePrice,
                weight: safeWeight,
                gst: String(prod.gst || "0").trim(),
                physicalStock: safeStock,
                openingStock: safeStock,
                purchasedStock: 0,
                soldStock: 0,
                damagedStock: 0,
                expiredStock: 0,
                reservedStock: 0,
                searchKey: String(prod.name || "").toLowerCase().trim(),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            };

            if (prod.expiryDate && String(prod.expiryDate).trim() !== "") {
                const parsedDate = new Date(prod.expiryDate);
                if (!isNaN(parsedDate.getTime())) {
                    cleanData.expiryDate = admin.firestore.Timestamp.fromDate(parsedDate);
                }
            }

            batch.set(docRef, cleanData, { merge: true });
            count++;
            
            if (count >= 490) break; // Firebase batch limit safety
        }

        await batch.commit();
        return { success: true, message: `Mission Accomplished: ${count} Master SKUs added to the Vault!` };

    } catch (error) {
        console.error("CRITICAL CRASH: ", error);
        throw new HttpsError('unknown', `CRASH REPORT: ${error.message}`);
    }
});


// ============================================================================
// 🤖 2. PREDICTIVE AUTO-PO ENGINE (GEN 2)
// ============================================================================
exports.runPredictivePOEngine = onSchedule("every day 00:00", async (event) => {
    console.log("🚀 Starting ClickOut Predictive AI Engine...");
    
    try {
        const productsSnap = await db.collection("products").where("isBlocked", "==", false).get();
        
        let suggestionsCount = 0;
        const batch = db.batch();

        for (const doc of productsSnap.docs) {
            const data = doc.data();
            const physicalStock = data.physicalStock || 0;
            const supplierId = data.supplierId || "DEFAULT_SUPPLIER";
            
            const dailyVelocity = data.avgDailySales || 5; 
            const leadTimeDays = data.supplierLeadTime || 3; 
            const safetyBuffer = data.safetyBuffer || 20;    
            
            const reorderPoint = (dailyVelocity * leadTimeDays) + safetyBuffer;

            if (physicalStock <= reorderPoint) {
                const orderQty = Math.ceil((dailyVelocity * 14) - physicalStock);
                
                if (orderQty > 0) {
                    const suggestionRef = db.collection("ai_po_suggestions").doc();
                    batch.set(suggestionRef, {
                        suggestionId: suggestionRef.id,
                        productId: doc.id,
                        productName: data.name || "Unknown Product",
                        currentStock: physicalStock,
                        recommendedQty: orderQty,
                        supplierId: supplierId,
                        reason: `Stock (${physicalStock}) hit Re-Order Point (${reorderPoint}). Velocity: ${dailyVelocity}/day.`,
                        status: "PENDING_APPROVAL",
                        createdAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                    suggestionsCount++;
                }
            }
        }

        if (suggestionsCount > 0) {
            await batch.commit();
            console.log(`✅ AI Engine Generated ${suggestionsCount} PO Suggestions!`);
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
    // Agar document delete ho gaya hai, toh claims set karne ki zarurat nahi
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
        concurrency: 80, // Gen 2 feature: Cost saver!
        memory: "512MiB"
    }, 
    async (event) => {
        const orderData = event.data?.data();
        const orderId = event.params.orderId;

        if (!orderData) return;

        let isFraudSuspected = false;
        let riskScore = 0;

        // Fraud Rule: Weight mismatch ya guard bypass
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
        memory: "256MiB" // Lightweight memory for fast execution
    }, 
    async (event) => {
        const orderData = event.data?.data();
        if (!orderData) return;

        // 1. Identifiers nikaalo (fallback ke sath for safety)
        const tenantId = orderData.tenantId || "default_tenant";
        const storeId = orderData.storeId || "default_store";
        
        // 2. Financials (Aapke db format ke hisaab se adjust kar lena)
        const totalAmount = Number(orderData.totalAmount || orderData.getTotal || 0);
        
        // Fraud check logic (taaki stats me bhi dikhe)
        let isFraud = 0;
        if (orderData.weightMismatchFlag || orderData.exitStatus === 'OVERRIDDEN') {
            isFraud = 1;
        }

        // 3. Date logic: YYYY-MM-DD (Store local timezone prefer karte hain)
        // Note: For global scale, GMT date use karna better hai
        const dateObj = new Date();
        const dateStr = dateObj.toISOString().split('T')[0]; 
        
        const statDocId = `${storeId}_${dateStr}`;
        const statRef = db.collection("daily_store_stats").doc(statDocId);

        // 4. Atomic Increment Operation
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
        // Calculate the date 90 days ago
        const ninetyDaysAgo = new Date();
        ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);
        const timestampLimit = admin.firestore.Timestamp.fromDate(ninetyDaysAgo);

        // Fetch old orders
        // Note: For 10M scale, you would need a more robust batching/pagination 
        // strategy here, but this is the core logic.
        const oldOrdersSnap = await db.collection("orders")
            .where("timestamp", "<=", timestampLimit)
            .limit(500) // Batch limit
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
        
        // Reminder: Ensure "Export to BigQuery" extension is active so data isn't lost!
    } catch (error) {
        console.error("🚨 Purge Engine Failed:", error);
    }
});